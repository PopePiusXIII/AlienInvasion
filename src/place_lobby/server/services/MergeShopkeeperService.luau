--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)
local GunApi = require(server_script_service.common.services.gun_api)

local TAG = "MergeShopkeeperService"
local MergeShopkeeperService = { Name = "MergeShopkeeperService" }

type MergeInventoryItem = {
	id: string,
	name: string,
	rarity: string,
	image: string,
}

local mergeInventoryUpdatedRemote: RemoteEvent
local requestMergeInventoryRemote: RemoteEvent
local mergeGunsRemote: RemoteEvent
local mergeResultRemote: RemoteEvent

local function getMergeInventory(player: Player): { MergeInventoryItem }?
	local guns = GunApi.getInventory(player)
	if not guns then
		return nil
	end

	local inventory: { MergeInventoryItem } = {}
	for _, gun in ipairs(guns) do
		local stats = assert(GunApi.getGunStats(player, gun.id), "MergeShopkeeperService requires stats for inventory gun " .. gun.id)
		assert(stats.image, "MergeShopkeeperService requires an image for inventory gun " .. gun.id)
		table.insert(inventory, {
			id = gun.id,
			name = gun.name,
			rarity = gun.rarity,
			image = stats.image,
		})
	end

	return inventory
end

local function sendInventory(player: Player)
	local inventory = getMergeInventory(player)
	if not inventory then
		Logger.fireClient(mergeResultRemote, player, false, "Profile is still loading")
		return
	end

	Logger.fireClient(mergeInventoryUpdatedRemote, player, inventory)
end

local function onRequestMergeInventory(player: Player)
	sendInventory(player)
end

local function hasThreeDistinctGunIds(gunIds: { string }): boolean
	if #gunIds ~= 3 then
		return false
	end

	local seen: { [string]: boolean } = {}
	for _, gunId in ipairs(gunIds) do
		if typeof(gunId) ~= "string" or seen[gunId] then
			return false
		end
		seen[gunId] = true
	end

	return true
end

local function onMergeGuns(player: Player, gunIds: { string })
	if typeof(gunIds) ~= "table" or not hasThreeDistinctGunIds(gunIds) then
		Logger.fireClient(mergeResultRemote, player, false, "Select exactly 3 distinct guns")
		return
	end

	local succeeded, _, failureReason = GunApi.mergeGuns(player, gunIds)
	if not succeeded then
		Logger.fireClient(mergeResultRemote, player, false, assert(failureReason, "Merge failure requires a reason"))
		return
	end

	sendInventory(player)
	Logger.fireClient(mergeResultRemote, player, true, "Merge complete")
end

local function getShopkeeperTemplate(): Model
	local assets = replicated_storage:WaitForChild("assets")
	local stores = assets:WaitForChild("stores")
	local foundry = stores:WaitForChild("foundry")
	local shopkeeper = foundry:WaitForChild("shopkeeper")
	assert(shopkeeper:IsA("Model"), "MergeShopkeeperService requires ReplicatedStorage.assets.stores.foundry.shopkeeper to be a Model")
	return shopkeeper
end

local function createMergePrompt(interactionPart: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MergePrompt"
	prompt.ActionText = "Merge"
	prompt.ObjectText = "Foundry"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = interactionPart
end

function MergeShopkeeperService:Init()
	mergeInventoryUpdatedRemote = Framework.CreateRemote("MergeInventoryUpdated")
	requestMergeInventoryRemote = Framework.CreateRemote("RequestMergeInventory")
	mergeGunsRemote = Framework.CreateRemote("MergeGuns")
	mergeResultRemote = Framework.CreateRemote("MergeResult")
	Logger.onServerEvent(requestMergeInventoryRemote, TAG, onRequestMergeInventory)
	Logger.onServerEvent(mergeGunsRemote, TAG, onMergeGuns)

	local shopkeeper = getShopkeeperTemplate():Clone()
	shopkeeper.Name = "MergeShopkeeper"
	shopkeeper.Parent = workspace

	local interactionPart = shopkeeper.PrimaryPart
	assert(interactionPart, "MergeShopkeeperService requires shopkeeper.PrimaryPart to be configured")
	createMergePrompt(interactionPart)
	Logger.info(TAG, "Spawned merge shopkeeper at %s.", shopkeeper:GetFullName())
end

function MergeShopkeeperService:Start() end

Framework.CreateService(MergeShopkeeperService)

return MergeShopkeeperService