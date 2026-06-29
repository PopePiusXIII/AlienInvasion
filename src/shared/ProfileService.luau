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

local TAG = "ProfileService"

local ProfileService = Framework.CreateService({ Name = TAG })

-- ── Profile shape ─────────────────────────────────────────────────────────────

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
		Logger.info(TAG, "Profile loaded for %s.", player.DisplayName)

		-- Fire callbacks so other services can react (e.g. sync to client HUD)
		for _, cb in ProfileLoadedCallbacks do
			task.spawn(function()
				local ok, err = pcall(cb, player, profile.Data :: PlayerProfile)
				if not ok then
					Logger.warn(TAG, "ProfileLoaded callback crashed: %s", tostring(err))
				end
			end)
		end
	else
		profile:EndSession()
	end
end

-- ── Starter weapons ───────────────────────────────────────────────────────────

local function grantStarterWeapons(profile: PlayerProfile)
	for _, weaponName in ipairs(Config.STARTER_UNLOCKED_WEAPONS :: { string }) do
		profile.unlockedWeapons[weaponName] = true
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

	-- Grant starter weapons on first load (async, non-blocking)
	local function ensureStarterWeapons(player: Player)
		local profile = ProfileService.WaitForProfile(player)
		if profile then
			grantStarterWeapons(profile)
		end
	end

	for _, player in Players:GetPlayers() do
		task.spawn(ensureStarterWeapons, player)
	end

	Players.PlayerAdded:Connect(ensureStarterWeapons)

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
		if not player.Parent then
			Logger.info(TAG, "WaitForProfile aborted — %s left.", player.Name)
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

--- Update a player's stats. ProfileStore auto-saves periodically.
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
end

--- Checks if a weapon is unlocked for the given player.
function ProfileService.isWeaponUnlocked(player: Player, weaponName: string): boolean
	local profile = ProfileService:GetProfile(player)
	if not profile then
		return false
	end
	return profile.unlockedWeapons[weaponName] == true
end

--- Attempts to unlock a weapon using gold. Returns (success, errorCode).
function ProfileService.tryUnlockWeapon(player: Player, weaponName: string): (boolean, string)
	local priceTable = Config.GOLD_WEAPON_UNLOCK_PRICES :: { [string]: number }
	local goldCost   = priceTable[weaponName]
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

return ProfileService
