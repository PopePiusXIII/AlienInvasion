--!strict
--------------------------------------------------------------------------------
-- ProfileDb.luau  (src/common → ServerScriptService.ServerModules.ProfileDb)
-- Wraps ProfileStore for cross-place player data persistence.
-- Used by both Lobby and Match places — DRY profile session management.
--
-- Public API:
--   ProfileDb.GetProfile(player): PlayerProfile?
--     Returns the cached profile for a player, or nil if not loaded.
--
--   ProfileDb.WaitForProfile(player): PlayerProfile
--     Blocks until the profile is ready (use during player init).
--
-- Lifecycle:
--   Init()  — Creates the ProfileStore instance.
--   Start() — Wires up Players.PlayerAdded / PlayerRemoving.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ServerScriptService.ServerModules.Logger)
local CombatConfig = require(ServerScriptService.ServerModules.CombatConfig)
local GunCore  = require(ServerScriptService.ServerModules.GunCore)
local GunMerge   = require(ServerScriptService.ServerModules.GunMerge)
local pst = require(ServerScriptService.ServerModules.ProfileDbTypes)

local TAG = "ProfileDb"

local ProfileDb = Framework.CreateService({ Name = TAG })

type PlayerProfile = pst.PlayerProfile
type EconomySummary = pst.EconomySummary
type GunInstance = GunCore.GunInstance
-- ── Profile shape ─────────────────────────────────────────────────────────────

local ONE_HUNDRED_GOLD_DEVELOPER_ID = 3608323068
local _FIVE_HUNDRED_GOLD_DEVELOPER_ID = "asdf"
local _ONE_THOUSAND_GOLD_DEVELOPER_ID = "asdfew"


-- Note: PROFILE_TEMPLATE uses defaults; unlockedWeapons is filled at runtime
-- via Reconcile() so Config can be referenced.
local PROFILE_TEMPLATE : PlayerProfile = {
	bestWave = 0,
	totalGames = 0,
	goldStuds = 0,
	lifetimeSilverEarned = 0,
	lifetimeSilverSpent = 0,
	unlockedWeapons = {},
	inventory = {},
}

-- ── ProfileStore (lazy-loaded from Packages) ─────────────────────────────────

local ProfileStore: any = nil
local PlayerStore: any     = nil

local function initProfileStore()
	if PlayerStore then return end

	local Packages = ReplicatedStorage:WaitForChild("Packages")
	ProfileStore = require(Packages:WaitForChild("ProfileStore"))
	PlayerStore  = ProfileStore.New("AlienInvasion_Profiles", PROFILE_TEMPLATE)
	Logger.info(TAG, "ProfileStore initialized.")
end

-- ── Active session cache ─────────────────────────────────────────────────────

local Profiles: { [Player]: any } = {}

-- ── Profile loaded callback (for services that need to react) ─────────────────

local ProfileLoadedCallbacks: { (player: Player, profile: PlayerProfile) -> () } = {}
local ProfileChangedCallbacks: { (player: Player, profile: PlayerProfile) -> () } = {}

function ProfileDb.OnProfileLoaded(callback: (player: Player, profile: PlayerProfile) -> ())
	table.insert(ProfileLoadedCallbacks, callback)
end

function ProfileDb.OnProfileChanged(callback: (player: Player, profile: PlayerProfile) -> ())
	table.insert(ProfileChangedCallbacks, callback)
end

local function notifyProfileChanged(player: Player, profile: PlayerProfile)
	for _, callback in ProfileChangedCallbacks do
		task.spawn(function()
			local ok, err = pcall(function() callback(player, profile) end)
			if not ok then
				Logger.warn(TAG, "ProfileChanged callback crashed: %s", tostring(err))
			end
		end)
	end
end

-- ── Session lifecycle ────────────────────────────────────────────────────────

local function grantStarterWeapons(session: any)
	for _, weaponName in ipairs(CombatConfig.STARTER_UNLOCKED_WEAPONS :: { string }) do
		session.Data.unlockedWeapons[weaponName] = true
	end
end

local function onPlayerAdded(player: Player)
	local profile = nil
	local attempts = 0
	local maxAttempts = 5

	while not profile and attempts < maxAttempts do
		attempts += 1
		Logger.info(TAG, "StartSessionAsync attempt %d/%d for %s.", attempts, maxAttempts, player.DisplayName)
		profile = PlayerStore:StartSessionAsync(tostring(player.UserId), {
			Cancel = function()
				return player.Parent == nil
			end,
		})

		if not profile and attempts < maxAttempts then
			Logger.warn(TAG, "Attempt %d failed for %s — retrying in %ds.", attempts, player.DisplayName, 2 ^ (attempts - 1))
			task.wait(2 ^ (attempts - 1)) -- Exponential backoff: 1s, 2s, 4s...
		end
	end

	if not profile then
		-- Only happens when the server is shutting down
		player:Kick("Profile load failed — please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
		player:Kick("Profile session ended — please rejoin.")
	end)

	if player.Parent then
		Profiles[player] = profile

		-- Grant starter weapons immediately while we have the profile,
		-- before marking the session as "ready" to other services.
		grantStarterWeapons(profile:: PlayerProfile)

		Logger.info(TAG, "Profile loaded for %s.", player.UserId)

		-- Fire callbacks so other services can react (e.g. sync to client HUD)
		for _, cb in ProfileLoadedCallbacks do
			task.spawn(function()
				local ok, err = pcall(function() cb(player, profile :: PlayerProfile) end)
				if not ok then
					Logger.warn(TAG, "ProfileLoaded callback crashed: %s", tostring(err))
				end
			end)
		end
	else
		profile:EndSession()
	end
end

-- ── Service lifecycle ────────────────────────────────────────────────────────

function ProfileDb:Init()
	initProfileStore()
	Logger.info(TAG, "ProfileDb initialized (ProfileStore backend).")
end

function ProfileDb:Start()
	local Players = game:GetService("Players")
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player: Player)
		local profile = Profiles[player]
		if profile then
			profile:EndSession({
				CleanupOnNonRecovery = true,
			})
		end
	end)

	-- Flush all profiles on server shutdown (Studio stop, crash, etc.)
	game:BindToClose(function()
		for _, session in Profiles do
			session:EndSession({
				CleanupOnNonRecovery = true,
			})
		end
		-- Give DataStore time to actually write before shutdown
		task.wait(1)
		Logger.info(TAG, "All profile sessions flushed on shutdown.")
	end)
end

-- ── Public API ───────────────────────────────────────────────────────────────

--- Returns the cached profile session for a player, or nil if not yet loaded.
function ProfileDb:GetSession(player: Player): any?
	return Profiles[player]
end

--- Returns the cached profile data for a player, or nil if not yet loaded.
function ProfileDb:GetProfile(player: Player): PlayerProfile?
	local session = Profiles[player]
	if not session then
		return nil
	end
	return session.Data :: PlayerProfile
end

--- Blocks until the profile session is ready, then returns the profile data.
--- Returns nil if the timeout (default 30 s) elapses or player left.
function ProfileDb:WaitForProfile(player: Player): PlayerProfile?
	local deadline = os.clock() + 30
	repeat
		task.wait(0.1)
		if not player or not player.Parent then
			Logger.info(TAG, "WaitForProfile aborted — player left.")
			return nil
		end
		if os.clock() > deadline then
			Logger.warn(TAG, "WaitForProfile timed out for %s.", player.Name)
			return nil
		end
	until Profiles[player]
	return Profiles[player].Data :: PlayerProfile
end

-- ── Data operations (merged from DataService) ────────────────────────────────

--- Save the player's profile to DataStore immediately.
function ProfileDb.save(player: Player)
	local session = Profiles[player]
	if not session then
		Logger.warn(TAG, "Cannot save for %s — session not active.", player.Name)
		return
	end

	local success, err = pcall(function()
		session:Save()
	end)

	if not success then
		Logger.warn(TAG, "Save failed for %s: %s", player.Name, tostring(err))
	end
end

--- Update a player's stats at end of game and save immediately.
function ProfileDb.saveStats(player: Player, waveReached: number, economy: EconomySummary?)
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot save stats for %s — profile not loaded.", player.Name)
		return
	end

	local silverEarned = economy and economy.silverEarned or 0
	local silverSpent  = economy and economy.silverSpent or 0
	local goldEarned   = economy and economy.goldEarned or 0

	profile.bestWave             = math.max(profile.bestWave, waveReached)
	profile.totalGames           = profile.totalGames + 1
	profile.lifetimeSilverEarned += silverEarned
	profile.lifetimeSilverSpent  += silverSpent
	profile.goldStuds            += goldEarned

	Logger.info(TAG, "Saved stats for %s — wave %d.", player.Name, waveReached)
	notifyProfileChanged(player, profile)
	ProfileDb.save(player)
end

--- Checks if a weapon is unlocked for the given player.
function ProfileDb.isWeaponUnlocked(player: Player, weaponName: string): boolean
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot unlock %s for %s — profile not loaded.", weaponName, player.Name)
		return false
	end
	return profile.unlockedWeapons[weaponName]
end

--- Attempts to unlock a weapon using gold. Returns (success, errorCode).
function ProfileDb.tryUnlockWeapon(player: Player, weaponName: string): (boolean, string)
    local gun = CombatConfig.GUN_STATS[weaponName] :: GunCore.Gun?

    local goldCost = gun and gun.gold_cost
    if goldCost == nil then
        return false, "UNKNOWN_WEAPON"
    end

	local profile = ProfileDb:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot unlock %s for %s — profile not loaded.", weaponName, player.Name)
		return false, "PROFILE_NOT_LOADED"
	end

	if profile.unlockedWeapons[weaponName] == true then
		return false, "ALREADY_UNLOCKED"
	end

	if profile.goldStuds < goldCost then
		return false, "INSUFFICIENT_GOLD"
	end

	profile.goldStuds -= goldCost
	profile.unlockedWeapons[weaponName] = true

	Logger.info(TAG, "%s unlocked %s for %d gold.", player.Name, weaponName, goldCost)
	notifyProfileChanged(player, profile)
	return true, "OK"
end

function ProfileDb.buyDeveloperGold(player: Player, dev_product_id: number): (boolean)
	-- Map developer product IDs to gold amounts.
	-- Replace the placeholder IDs with your actual product IDs from the Roblox Creator Hub.
	local goldRewards = {
		[ONE_HUNDRED_GOLD_DEVELOPER_ID] = 100,   -- Example: Small pack
		[12345679] = 500,   -- Example: Medium pack
		[12345680] = 1000,  -- Example: Large pack
	}

	local goldAmount = goldRewards[dev_product_id]
	if not goldAmount then
		Logger.warn(TAG, "Unknown dev product ID %d from player %s.", dev_product_id, player.Name)
		return false
	end

	local profile = ProfileDb:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot grant gold to %s — profile not loaded.", player.Name)
		return false
	end

	profile.goldStuds += goldAmount
	Logger.info(TAG, "%s purchased %d gold via dev product %d.", player.Name, goldAmount, dev_product_id)

	-- Save immediately so purchase data isn't lost on server crash.
	ProfileDb.save(player)
	notifyProfileChanged(player, profile)

	return true
end

-- ── Inventory management (gun instances with UUIDs) ───────────────────────────

--- Generate a new gun instance ID using HttpService GUID (unguessable by client).
local function generateGunId(): string
	return HttpService:GenerateGUID():upper()
end

--- Grant a gun to the player's inventory at common rarity, level 1.
--- Returns the new gun instance ID, or nil if profile not loaded.
function ProfileDb.grantGun(player: Player, gunName: string): string?
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot grant %s to %s — profile not loaded.", gunName, player.Name)
		return nil
	end

	-- Validate that the base gun exists in GUN_STATS (check common variant)
	local statsKey = CombatConfig.getGunStatsKey(gunName, "common")
	if not CombatConfig.GUN_STATS[statsKey] then
		Logger.warn(TAG, "Cannot grant %s — no common variant in GUN_STATS.", gunName)
		return nil
	end

	-- Mark as unlocked (for backward compat with isWeaponUnlocked checks)
	profile.unlockedWeapons[gunName] = true

	local id = generateGunId()
	profile.inventory[id] = {
		id = id,
		name = gunName,
		rarity = "common",
	}

	Logger.info(TAG, "%s granted %s (id=%s, common).", player.Name, gunName, id)
	ProfileDb.save(player)
	return id
end

--- Get all gun instances from the player's profile.
function ProfileDb.getInventory(player: Player): { GunInstance }?
	local profile = ProfileDb:GetProfile(player)
	if not profile then return nil end

	local result: { GunInstance } = {}
	for _, instance in profile.inventory do
		table.insert(result, instance :: GunInstance)
	end
	return result
end

--- Get a single gun instance by ID.
function ProfileDb.getGun(player: Player, gunId: string): GunInstance?
	local profile = ProfileDb:GetProfile(player)
	if not profile then return nil end
	return profile.inventory[gunId] :: GunInstance?
end

--- Remove a gun from the player's inventory by ID.
function ProfileDb.removeGun(player: Player, gunId: string): boolean
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot remove %s from %s — profile not loaded.", gunId, player.Name)
		return false
	end

	local instance = profile.inventory[gunId]
	if not instance then
		Logger.warn(TAG, "Gun %s not found in %s's inventory.", gunId, player.Name)
		return false
	end

	profile.inventory[gunId] = nil
	Logger.info(TAG, "%s removed %s (%s).", player.Name, instance.name, gunId)
	ProfileDb.save(player)
	return true
end

--- Upgrade a gun's rarity by merging multiple same-rarity instances.
--- Consumes the source guns and grants one at the next rarity tier (level resets to 1).
--- Returns (success, newGunId?, errorMessage?).
function ProfileDb.mergeGuns(player: Player, gunIds: { string }): (boolean, string?, string?)
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		return false, nil, "PROFILE_NOT_LOADED"
	end

	if #gunIds < 2 then
		return false, nil, "NOT_ENOUGH_GUNS"
	end

	-- Collect and validate all source instances
	local instances: { GunInstance } = {}
	for _, gid in ipairs(gunIds) do
		local inst = profile.inventory[gid] :: GunInstance?
		if not inst then
			return false, nil, "GUN_NOT_FOUND"
		end
		table.insert(instances, inst)
	end

	-- All must share the same name and rarity
	local first = instances[1]
	for _, inst in ipairs(instances) do
		if inst.name ~= first.name or inst.rarity ~= first.rarity then
			return false, nil, "MISMATCHED_GUNS"
		end
	end

	-- Determine upgraded rarity via GunMerge rules
	local newRarity = GunMerge.merge_guns(instances :: { GunInstance })
	if newRarity == first.rarity then
		return false, nil, "CANNOT_UPGRADE_FURTHER"
	end

	-- Validate the target variant exists in GUN_STATS
	local targetKey = CombatConfig.getGunStatsKey(first.name, newRarity)
	if not CombatConfig.GUN_STATS[targetKey] then
		Logger.warn(TAG, "Target variant %s not found in GUN_STATS.", targetKey)
		return false, nil, "TARGET_VARIANT_MISSING"
	end

	-- Consume source guns
	for _, inst in ipairs(instances) do
		profile.inventory[inst.id] = nil
	end

	-- Grant upgraded gun (level resets to 1 in InventoryService on match start)
	local id = generateGunId()
	profile.inventory[id] = {
		id = id,
		name = first.name,
		rarity = newRarity,
	}

	Logger.info(TAG, "%s merged %d %s %s → %s (id=%s).",
		player.Name, #instances, first.rarity, first.name, newRarity, id)
	ProfileDb.save(player)
	return true, id, nil
end

--- Upgrade a gun's level (1→2→3→4). In-memory only — not persisted to profile.
--- Returns (success, newLevel?, errorMessage?).
function ProfileDb.upgradeLevel(player: Player, gunId: string): (boolean, number?, string?)
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		return false, nil, "PROFILE_NOT_LOADED"
	end

	-- Just validate the gun exists in profile; level is tracked by InventoryService
	local instance = profile.inventory[gunId]
	if not instance then
		return false, nil, "GUN_NOT_FOUND"
	end

	Logger.info(TAG, "%s upgraded %s via RNG (in-memory).", player.Name, instance.name)
	-- Level tracking is delegated to InventoryService; this method just validates ownership.
	return true, nil, nil
end

--- Resolve full stats for a gun instance (base rarity stats + level multipliers).
--- `level` is passed in by the caller (InventoryService tracks it in-memory per match).
--- Defaults to 1 if not provided.
function ProfileDb.getGunStats(player: Player, gunId: string, level: number?): GunCore.Gun?
	local profile = ProfileDb:GetProfile(player)
	if not profile then return nil end

	local instance = profile.inventory[gunId] :: GunInstance?
	if not instance then return nil end

	-- Look up the rarity-specific base stats
	local statsKey = CombatConfig.getGunStatsKey(instance.name, instance.rarity)
	local base = CombatConfig.GUN_STATS[statsKey]
	if not base then
		Logger.warn(TAG, "No stats for %s.", statsKey)
		return nil
	end

	-- Apply level modifier (default to 1 if caller didn't provide)
	local effectiveLevel = level or 1
	local mod: GunCore.GunLevelModifier = CombatConfig.LEVEL_MULTIPLIERS[effectiveLevel] :: GunCore.GunLevelModifier
	     or CombatConfig.LEVEL_MULTIPLIERS[1] :: GunCore.GunLevelModifier

	return {
		rarity         = instance.rarity,
		damage         = math.floor(base.damage * mod.damage),
		gold_cost      = base.gold_cost,
		image          = base.image,
		range          = math.floor(base.range * mod.range),
		fireCooldown   = base.fireCooldown / mod.cooldownDiv,
		magSize        = math.max(1, math.floor(base.magSize * mod.magSize)),
		max_ammo       = base.max_ammo,
		reloadTime     = base.reloadTime,
		isAutomatic    = base.isAutomatic,
		isShotgun      = base.isShotgun,
		knockbackForce = math.floor(base.knockbackForce * mod.knockback),
		tracer         = base.tracer,
	}
end

local ProfileDbAPI: Framework.Module & pst.API = ProfileDb :: (Framework.Module & pst.API)

return ProfileDbAPI
