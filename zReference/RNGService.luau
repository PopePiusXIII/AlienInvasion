--!strict
--------------------------------------------------------------------------------
-- RNGService.luau  (src/server/services)
-- Handles in-game RNG block activation.
-- When a player hits the RNG block, their equipped gun's level increases (1→4).
-- If already at max level, grants gold bonus instead.
-- Level is tracked in-memory by InventoryService (resets each match).
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework     = require(ReplicatedStorage.Shared.Framework)
local Logger        = require(ReplicatedStorage.Shared.Logger)
local Config        = require(ReplicatedStorage.Shared.Config)
local RemoteNames   = require(ReplicatedStorage.Shared.RemoteNames)
local ProfileService = require(ReplicatedStorage.Shared.ProfileService)

local TAG = "RNGService"
local RNGService = Framework.CreateService({ Name = TAG })

-- ── State ────────────────────────────────────────────────────────────────────

local _rngActivateRemote:     RemoteEvent
local _rngTopupRemote:        RemoteEvent
local _rngRequestGiveRemote:  RemoteEvent
local _playerLocks:           { [number]: boolean } = {}
local _lastActivateTime:      { [number]: number }  = {}

-- Gold granted when RNG rolls a max-level gun
local MAX_LEVEL_GOLD_BONUS = 50

-- Lazy-loaded to avoid circular dependency.
local InventoryService = nil

local function ensureInventoryService()
	if not InventoryService then
		InventoryService = Framework.GetService("InventoryService")
	end
end

--- Runs a function with a per-player lock; guarantees unlock even on error.
local function withPlayerLock(uid: number, fn: () -> ())
	if _playerLocks[uid] then return end
	_playerLocks[uid] = true
	local ok, err = pcall(fn)
	_playerLocks[uid] = nil
	if not ok then
		Logger.warn(TAG, "pcall failed: %s", tostring(err))
	end
end

--- Top up ammo on the equipped gun using resolved stats.
local function topUpEquippedAmmo(player: Player)
	ensureInventoryService()
	local equippedGunId = InventoryService.getEquippedGunId(player)
	if not equippedGunId then return end

	-- Get current in-memory level for stat resolution
	local level = InventoryService.getGunLevel(player, equippedGunId)
	local gun = ProfileService.getGunStats(player, equippedGunId, level)
	if not gun then return end

	-- getGunStats doesn't return a name, fetch it from the profile instance
	local instance = ProfileService.getGun(player, equippedGunId)
	local displayName = instance and instance.name or ""

	Logger.info(TAG, "Topping up ammo for %s (%s, level %d).", player.Name, displayName, level)
	_rngTopupRemote:FireClient(player, displayName, gun.magSize, gun.max_ammo)
end

-- ── Remote Handlers ──────────────────────────────────────────────────────────

local function handleRngActivate(player: Player)
	local uid = player.UserId
	local now = tick()
	local last = _lastActivateTime[uid]
	if last and now - last < 0.5 then
		Logger.info(TAG, "Ignoring duplicate RNG_ACTIVATE from %s (cooldown)", player.Name)
		return
	end
	_lastActivateTime[uid] = now

	-- Destroy the RNG block in workspace.
	local rngPart = workspace:FindFirstChild("RNG BLOCK", true)
	if rngPart then
		rngPart:Destroy()
		Logger.info(TAG, "Destroyed RNG BLOCK for %s", player.Name)
	else
		Logger.info(TAG, "No RNG BLOCK found to destroy for %s", player.Name)
	end

	withPlayerLock(uid, function()
		ensureInventoryService()

		-- Get the player's currently equipped gun
		local equippedGunId = InventoryService.getEquippedGunId(player)
		if not equippedGunId then
			Logger.warn(TAG, "No equipped gun for %s — RNG block had no effect.", player.Name)
			return
		end

		local instance = ProfileService.getGun(player, equippedGunId)
		if not instance then
			Logger.warn(TAG, "Equipped gun %s not found in profile for %s.", equippedGunId, player.Name)
			return
		end

		-- Try to upgrade level (1→2→3→4) via InventoryService (in-memory)
		local success, newLevel, errorMsg = InventoryService.upgradeGunLevel(player, equippedGunId)

		if success and newLevel then
			Logger.info(TAG, "%s's %s upgraded to level %d via RNG.", player.Name, instance.name, newLevel)
			topUpEquippedAmmo(player)
		elseif errorMsg == "MAX_LEVEL" then
			-- Grant gold bonus instead
			local profile = ProfileService:GetProfile(player)
			if profile then
				profile.goldStuds += MAX_LEVEL_GOLD_BONUS
				Logger.info(TAG, "%s's %s is max level — granted %d gold.", player.Name, instance.name, MAX_LEVEL_GOLD_BONUS)
				ProfileService.save(player)
				ProfileService:SyncToClient(player)
			end

			-- Still top up ammo
			topUpEquippedAmmo(player)
		else
			Logger.warn(TAG, "Failed to upgrade %s's gun: %s", player.Name, tostring(errorMsg))
		end
	end)
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────

function RNGService:Init()
	_rngActivateRemote     = Framework.CreateRemote(RemoteNames.RNG_ACTIVATE)
	_rngTopupRemote        = Framework.CreateRemote(RemoteNames.RNG_TOPUP_AMMO)
	_rngRequestGiveRemote  = Framework.CreateRemote(RemoteNames.RNG_REQUEST_GIVE)
	-- Required by ProfileService:SyncToClient (not created in match place otherwise)
	Framework.CreateRemote(RemoteNames.SYNC_PROFILE)
end

function RNGService:Start()
	_rngActivateRemote.OnServerEvent:Connect(handleRngActivate)
	_rngRequestGiveRemote.OnServerEvent:Connect(function(player: Player, weaponName: string, slot: number?, _toRemove: string?)
		-- Grant the rolled weapon to the player's inventory
		local success = ProfileService.grantGun(player, weaponName)
		if success then
			Logger.info(TAG, "%s received %s from RNG prompt.", player.Name, weaponName)
		else
			Logger.warn(TAG, "Failed to grant %s to %s via RNG.", weaponName, player.Name)
		end
	end)

	-- Sync unlocked weapons to client via Player attribute (no remote needed)
	local Players = game:GetService("Players")
	local function syncUnlockedWeapons(player: Player)
		task.defer(function()
			local profile = ProfileService:GetProfile(player)
			if not profile then return end
			local names: { string } = {}
			for _, instance in profile.inventory do
				table.insert(names, instance.name)
			end
			player:SetAttribute("RngUnlockedWeapons", table.concat(names, ","))
			Logger.info(TAG, "Synced %d unlocked weapons to %s.", #names, player.Name)
		end)
	end

	-- Sync for existing players
	for _, p in Players:GetPlayers() do
		syncUnlockedWeapons(p)
	end

	-- Sync on profile load (in case it's not ready yet)
	ProfileService.OnProfileLoaded(function(player, _profile)
		syncUnlockedWeapons(player)
	end)
end

return RNGService
