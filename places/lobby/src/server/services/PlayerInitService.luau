--!strict
--------------------------------------------------------------------------------
-- PlayerInitService.luau  (places/lobby/src/server/services)
-- After profile loads, syncs it to the client so the HUD can display gold/silver.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework   = require(ReplicatedStorage.Shared.Framework)
local Logger      = require(ReplicatedStorage.Shared.Logger)
local ProfileService = require(ReplicatedStorage.Shared.ProfileService)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local TAG = "PlayerInitService"

local PlayerInitService = Framework.CreateService({ Name = TAG })

function PlayerInitService:Init()
	-- Create the SyncProfile remote so ProfileService can fire it
	Framework.CreateRemote(RemoteNames.SYNC_PROFILE)
end

function PlayerInitService:Start()
	Logger.info(TAG, "Starting — will sync profiles for existing players.")

	local function syncProfile(player: Player)
		Logger.info(TAG, "Waiting for profile for %s.", player.DisplayName)
		local success, result = pcall(function()
			return ProfileService.WaitForProfile(player)
		end)
		if not success then
			Logger.warn(TAG, "WaitForProfile CRASHED for %s: %s", player.DisplayName, tostring(result))
			return
		end
		local profile = result
		if not profile then
			Logger.warn(TAG, "No profile for %s — timed out or failed.", player.DisplayName)
			return
		end
		Logger.info(TAG, "Got profile for %s — gold=%d, silver=%d.", player.DisplayName, profile.goldStuds, profile.lifetimeSilverEarned - profile.lifetimeSilverSpent)
		local success2, err = pcall(function()
			ProfileService:SyncToClient(player)
		end)
		if not success2 then
			Logger.warn(TAG, "SyncToClient CRASHED for %s: %s", player.DisplayName, tostring(err))
			return
		end
		Logger.info(TAG, "Sync fired for %s.", player.DisplayName)
	end

	-- Handle players who joined before Start() ran (e.g. in Studio)
	local existingPlayers = Players:GetPlayers()
	Logger.info(TAG, "Found %d existing player(s).", #existingPlayers)
	for _, player in existingPlayers do
		task.spawn(syncProfile, player)
	end

	-- Handle future joins
	Players.PlayerAdded:Connect(function(player)
		Logger.info(TAG, "PlayerAdded fired for %s.", player.DisplayName)
		syncProfile(player)
	end)

	Logger.info(TAG, "Start complete.")
end

return PlayerInitService

