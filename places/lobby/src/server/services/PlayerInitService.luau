--!strict
--------------------------------------------------------------------------------
-- PlayerInitService.luau  (places/lobby/src/server/services)
-- After profile loads, syncs it to the client so the HUD can display gold/silver.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Framework   = require(ReplicatedStorage.Shared.Framework)
local Logger      = require(ReplicatedStorage.Shared.Logger)
local ProfileService = require(ServerScriptService.ServerModules.ProfileService)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local TAG = "PlayerInitService"

local PlayerInitService = Framework.CreateService({ Name = TAG })

function PlayerInitService:Init()
	-- Create the SyncProfile remote so ProfileService can fire it
	Framework.CreateRemote(RemoteNames.SYNC_PROFILE)

	-- Create the weapon purchase remote
	local purchaseRemote = Framework.CreateRemote(RemoteNames.PURCHASE_WEAPON)
	purchaseRemote.OnServerEvent:Connect(function(player: Player, weaponName: string)
		Logger.info(TAG, "%s wants to buy %s.", player.Name, weaponName)

		-- Attempt to unlock with gold
		local success, errorCode = ProfileService.tryUnlockWeapon(player, weaponName)
		if success then
			Logger.info(TAG, "%s purchased %s with gold.", player.Name, weaponName)
			ProfileService:SyncToClient(player)
			return
		end

		-- If they don't have enough gold, prompt for developer product purchase
		if errorCode == "INSUFFICIENT_GOLD" then
			Logger.info(TAG, "%s doesn't have enough gold for %s — prompting dev product.", player.Name, weaponName)
			MarketplaceService:PromptProductPurchase(player, 3608323068) -- Replace with your gold product ID
		else
			Logger.warn(TAG, "%s purchase failed: %s", player.Name, errorCode)
		end
	end)
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

	-- Register callback so we react immediately when ProfileService loads a profile.
	ProfileService.OnProfileLoaded(function(player: Player, profile: any)
		Logger.info(TAG, "ProfileLoaded callback for %s — gold=%d, silver=%d.", player.DisplayName, profile.goldStuds, profile.lifetimeSilverEarned - profile.lifetimeSilverSpent)
		local success, err = pcall(function()
			ProfileService:SyncToClient(player)
		end)
		if not success then
			Logger.warn(TAG, "SyncToClient CRASHED for %s: %s", player.DisplayName, tostring(err))
			return
		end
		Logger.info(TAG, "Sync fired for %s.", player.DisplayName)
	end)

	-- Handle players who joined before Start() ran (e.g. in Studio)
	local existingPlayers = Players:GetPlayers()
	Logger.info(TAG, "Found %d existing player(s).", #existingPlayers)
	for _, player in existingPlayers do
		task.spawn(syncProfile, player)
	end

	-- Future joins are handled by the OnProfileLoaded callback above.
	Logger.info(TAG, "Start complete.")
end

return PlayerInitService

