--!strict
--------------------------------------------------------------------------------
-- profile_db.luau  (src/common → server_script_service.profile_db)
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

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.common.shared.framework)
local Logger    = require(replicated_storage.common.shared.logger)
local ProfileDbType = require(replicated_storage.common.shared.profile_db_types)
local ProfileDbDev = require(server_script_service.common.services:WaitForChild("profile_db_dev"))
local ProfileDbMigrations = require(server_script_service.common.services:WaitForChild("profile_db_migrations"))

local TAG = "ProfileDb"

-- Keep this table locally inferred while its methods are added below. The API
-- check at the end of the file then verifies the complete implementation.
local ProfileDb = { Name = TAG }

type PlayerProfile = ProfileDbType.PlayerProfile
-- ── Profile shape ─────────────────────────────────────────────────────────────

-- Note: PROFILE_TEMPLATE uses defaults; unlockedWeapons is filled at runtime
-- via Reconcile() so Config can be referenced.
local PROFILE_TEMPLATE : PlayerProfile = {
	schemaVersion = 0,
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

	local Packages = replicated_storage:WaitForChild("Packages")
	ProfileStore = require(Packages:WaitForChild("ProfileStore"))
	local storeName = ProfileDbDev.getStoreName("AlienInvasion_Profiles")
	PlayerStore = ProfileStore.New(storeName, PROFILE_TEMPLATE)
	Logger.info(TAG, "ProfileStore initialized with store %s.", storeName)
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

function ProfileDb.NotifyChanged(player: Player, profile: PlayerProfile)
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
	if ProfileDbDev.isEnabled() then
		local profileName = ProfileDbDev.applyActiveProfile(profile.Data, ProfileDbMigrations.CURRENT_SCHEMA_VERSION)
		Logger.info(TAG, "Applied Studio dev profile %s.", profileName)
	end
	ProfileDbMigrations.apply(profile.Data)

	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
		player:Kick("Profile session ended — please rejoin.")
	end)

	if player.Parent then
		Profiles[player] = profile

		Logger.info(TAG, "Profile loaded for %s.", player.UserId)

		-- Fire callbacks so other services can react (e.g. sync to client HUD)
		for _, cb in ProfileLoadedCallbacks do
			task.spawn(function()
				local ok, err = pcall(function() cb(player, profile.Data :: PlayerProfile) end)
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

-- Check the implementation directly against the public API. Keep this check
-- separate from Framework.Module because Framework.Module intentionally has an
-- `[any]: any` indexer for generic services.
local ProfileDbAPI: ProfileDbType.API = ProfileDb

-- CreateService preserves the concrete service type, so no cast is needed at
-- the registration boundary.
Framework.CreateService(ProfileDb)

return ProfileDbAPI
