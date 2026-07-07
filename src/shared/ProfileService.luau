--!strict
--------------------------------------------------------------------------------
-- ProfileService.luau  (src/shared → ReplicatedStorage.Shared.ProfileService)
-- Wraps ProfileStore for cross-place player data persistence.
-- Used by both Lobby and Match places — DRY profile session management.
--
-- Public API:
--   ProfileService.GetProfile(player): PlayerProfile?
--     Returns the cached profile for a player, or nil if not loaded.
--
--   ProfileService.WaitForProfile(player): PlayerProfile
--     Blocks until the profile is ready (use during player init).
--
-- Lifecycle:
--   Init()  — Creates the ProfileStore instance.
--   Start() — Wires up Players.PlayerAdded / PlayerRemoving.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)

local TAG = "ProfileService"

local ProfileService = Framework.CreateService({ Name = TAG })

-- ── Profile shape ─────────────────────────────────────────────────────────────

local ONE_HUNDRED_GOLD_DEVELOPER_ID = 3608323068
local FIVE_HUNDRED_GOLD_DEVELOPER_ID = "asdf"
local ONE_THOUSAND_GOLD_DEVELOPER_ID = "asdfew"

export type PlayerProfile = {
	bestWave: number,
	totalGames: number,
	goldStuds: number,
	lifetimeSilverEarned: number,
	lifetimeSilverSpent: number,
	unlockedWeapons: { [string]: boolean },
}

export type EconomySummary = {
	silverEarned: number,
	silverSpent: number,
	goldEarned: number,
}

-- Note: PROFILE_TEMPLATE uses defaults; unlockedWeapons is filled at runtime
-- via Reconcile() so Config can be referenced.
local PROFILE_TEMPLATE = {
	bestWave = 0,
	totalGames = 0,
	goldStuds = 0,
	lifetimeSilverEarned = 0,
	lifetimeSilverSpent = 0,
	unlockedWeapons = {},
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

function ProfileService.OnProfileLoaded(callback: (player: Player, profile: PlayerProfile) -> ())
	table.insert(ProfileLoadedCallbacks, callback)
end

-- ── Session lifecycle ────────────────────────────────────────────────────────

local function grantStarterWeapons(profile: PlayerProfile)
	for _, weaponName in ipairs(CombatConfig.STARTER_UNLOCKED_WEAPONS :: { string }) do
		profile.Data.unlockedWeapons[weaponName] = true
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
				local ok, err = pcall(cb, player, profile :: PlayerProfile)
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

function ProfileService:Init()
	initProfileStore()
	Logger.info(TAG, "ProfileService initialized (ProfileStore backend).")
end

function ProfileService:Start()
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
function ProfileService:GetSession(player: Player): any?
	return Profiles[player]
end

--- Returns the cached profile data for a player, or nil if not yet loaded.
function ProfileService:GetProfile(player: Player): PlayerProfile?
	local session = Profiles[player]
	if not session then
		return nil
	end
	return session.Data :: PlayerProfile
end

--- Blocks until the profile session is ready, then returns the profile data.
--- Returns nil if the timeout (default 30 s) elapses or player left.
function ProfileService:WaitForProfile(player: Player): PlayerProfile?
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

--- Sends current gold/silver balance to the client HUD.
function ProfileService:SyncToClient(player: Player)
	local profile = ProfileService:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot sync profile for %s — not loaded.", player.Name)
		return
	end

	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
	local remote = Remotes:WaitForChild(RemoteNames.SYNC_PROFILE) :: RemoteEvent
	remote:FireClient(player, profile.goldStuds, profile.lifetimeSilverEarned - profile.lifetimeSilverSpent)
	Logger.info(TAG, "Synced profile to %s — gold=%d, silver=%d.", player.Name, profile.goldStuds, profile.lifetimeSilverEarned - profile.lifetimeSilverSpent)
end

-- ── Data operations (merged from DataService) ────────────────────────────────

--- Save the player's profile to DataStore immediately.
function ProfileService.save(player: Player)
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
function ProfileService.saveStats(player: Player, waveReached: number, economy: EconomySummary?)
	local profile = ProfileService:GetProfile(player)
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
	ProfileService.save(player)
end

--- Checks if a weapon is unlocked for the given player.
function ProfileService.isWeaponUnlocked(player: Player, weaponName: string): boolean
	local profile = ProfileService:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot unlock %s for %s — profile not loaded.", weaponName, player.Name)
		return false
	end
	return profile.unlockedWeapons[weaponName]
end

--- Attempts to unlock a weapon using gold. Returns (success, errorCode).
function ProfileService.tryUnlockWeapon(player: Player, weaponName: string): (boolean, string)
    local gunStats = CombatConfig.GUN_STATS[weaponName]

    local goldCost = gunStats.gold_cost
    if goldCost == nil then
        return false, "UNKNOWN_WEAPON"
    end

	local profile = ProfileService:GetProfile(player)
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
	return true, "OK"
end

function ProfileService.buyDeveloperGold(player: Player, dev_product_id: number): (boolean)
	-- Map developer product IDs to gold amounts.
	-- Replace the placeholder IDs with your actual product IDs from the Roblox Creator Hub.
	local goldRewards = {
		[ONE_HUNDRED_GOLD_DEVELOPER_ID] = 100,   -- Example: Small pack
		[12345679] = FIVE_HUNDRED_GOLD_DEVELOPER_ID,   -- Example: Medium pack
		[12345680] = ONE_THOUSAND_GOLD_DEVELOPER_ID,  -- Example: Large pack
	}

	local goldAmount = goldRewards[dev_product_id]
	if not goldAmount then
		Logger.warn(TAG, "Unknown dev product ID %d from player %s.", dev_product_id, player.Name)
		return false
	end

	local profile = ProfileService:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot grant gold to %s — profile not loaded.", player.Name)
		return false
	end

	profile.goldStuds += goldAmount
	Logger.info(TAG, "%s purchased %d gold via dev product %d.", player.Name, goldAmount, dev_product_id)

	-- Save immediately so purchase data isn't lost on server crash.
	ProfileService.save(player)

	-- Sync updated balance to the client HUD.
	task.spawn(function()
		local ok, err = pcall(function()
			ProfileService:SyncToClient(player)
		end)
		if not ok then
			Logger.warn(TAG, "Failed to sync profile after purchase: %s", tostring(err))
		end
	end)

	return true
end




return ProfileService