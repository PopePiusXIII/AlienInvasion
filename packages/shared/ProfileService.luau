--!strict
--------------------------------------------------------------------------------
-- ProfileService.luau  (packages/shared → ReplicatedStorage.Shared.ProfileService)
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

-- ── Session lifecycle ────────────────────────────────────────────────────────

local function onPlayerAdded(player: Player)
	local profile = nil
	local attempts = 0
	local maxAttempts = 5

	while not profile and attempts < maxAttempts do
		attempts += 1
		profile = PlayerStore:StartSessionAsync(tostring(player.UserId), {
			Cancel = function()
				return player.Parent == nil
			end,
		})

		if not profile and attempts < maxAttempts then
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
	else
		profile:EndSession()
	end
end

-- ── Service lifecycle ────────────────────────────────────────────────────────

function ProfileService:Init()
	initProfileStore()
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
function ProfileService:WaitForProfile(player: Player): PlayerProfile
	repeat
		task.wait(0.1)
	until Profiles[player]
	return Profiles[player].Data :: PlayerProfile
end

return ProfileService
