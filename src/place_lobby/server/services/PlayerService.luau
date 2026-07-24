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
local _syncProfileRemote: RemoteEvent

local function syncProfile(player: Player, profile: any)
	local unlockedWeapons = {}
	for weaponName, unlocked in profile.unlockedWeapons do
		if unlocked then
			table.insert(unlockedWeapons, weaponName)
		end
	end

	local inventory = {}
	for id, item in profile.inventory do
		table.insert(inventory, {
			id = id,
			name = item.name,
			rarity = item.rarity,
		})
	end

	_syncProfileRemote:FireClient(
		player,
		profile.goldStuds,
		profile.lifetimeSilverEarned - profile.lifetimeSilverSpent,
		unlockedWeapons,
		inventory
	)
	Logger.info(TAG, "Synced profile to %s — gold=%d, silver=%d.", player.Name, profile.goldStuds, profile.lifetimeSilverEarned - profile.lifetimeSilverSpent)
end

function PlayerInitService:Init()
	_syncProfileRemote = Framework.CreateRemote(RemoteNames.SYNC_PROFILE)

	-- Create the weapon purchase remote
	local purchaseRemote = Framework.CreateRemote(RemoteNames.PURCHASE_WEAPON)
	purchaseRemote.OnServerEvent:Connect(function(player: Player, weaponName: string)
		Logger.info(TAG, "%s wants to buy %s.", player.Name, weaponName)

		-- Attempt to unlock with gold
		local success, errorCode = ProfileService.tryUnlockWeapon(player, weaponName)
		if success then
			Logger.info(TAG, "%s purchased %s with gold.", player.Name, weaponName)
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
	ProfileService.OnProfileLoaded(syncProfile)
	ProfileService.OnProfileChanged(syncProfile)

	for _, player in Players:GetPlayers() do
		local profile = ProfileService:GetProfile(player)
		if profile then
			syncProfile(player, profile)
		end
	end

	Logger.info(TAG, "Profile sync listeners connected.")
end

return PlayerInitService
