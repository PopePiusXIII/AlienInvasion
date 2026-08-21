--!strict

local Players = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)
local MergeHud = require(replicated_storage.common.shared.vide.merge)

local MergeShopkeeperController = { Name = "MergeShopkeeperController" }

type MergeInventoryItem = {
	id: string,
	name: string,
	rarity: string,
	image: string,
}

local localPlayer = assert(Players.LocalPlayer, "MergeShopkeeperController requires a local player")
local mergeInventoryUpdatedRemote: RemoteEvent
local requestMergeInventoryRemote: RemoteEvent
local mergeGunsRemote: RemoteEvent
local mergeResultRemote: RemoteEvent
local selectedGunIds: { string } = {}

local function setStatus(text: string)
	MergeHud.sources.status(text)
end

local function syncSelection()
	MergeHud.sources.selectedIds(table.clone(selectedGunIds))
	setStatus(string.format("Selected %d / 3 guns", #selectedGunIds))
end

local function closeMergeHud()
	MergeHud.sources.visible(false)
end

local function openMergeHud()
	MergeHud.sources.visible(true)
	requestMergeInventoryRemote:FireServer()
end

local function selectGun(gunId: string)
	local index = table.find(selectedGunIds, gunId)
	if index then
		table.remove(selectedGunIds, index)
	elseif #selectedGunIds < 3 then
		table.insert(selectedGunIds, gunId)
	else
		setStatus("Select exactly 3 matching guns")
		return
	end
	syncSelection()
end

local function requestMerge()
	if #selectedGunIds ~= 3 then
		setStatus("Select exactly 3 matching guns")
		return
	end
	mergeGunsRemote:FireServer(selectedGunIds)
end

local function onMergeInventoryUpdated(guns: { MergeInventoryItem })
	selectedGunIds = {}
	MergeHud.sources.selectedIds({})
	MergeHud.sources.inventory(guns)
	setStatus("Select 3 matching guns")
end

local function onMergeResult(succeeded: boolean, result: string)
	setStatus(if succeeded then "Merge complete" else "Merge failed: " .. result)
end

local function getShopkeeperTemplate(): Model
	local assets = replicated_storage:WaitForChild("assets")
	local stores = assets:WaitForChild("stores")
	local foundry = stores:WaitForChild("foundry")
	local shopkeeper = foundry:WaitForChild("shopkeeper")
	assert(shopkeeper:IsA("Model"), "MergeShopkeeperController requires ReplicatedStorage.assets.stores.foundry.shopkeeper to be a Model")
	return shopkeeper
end

local function createMergePrompt(part: BasePart): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MergePrompt"
	prompt.ActionText = "Merge"
	prompt.ObjectText = "Foundry"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function spawnShopkeeper(): ProximityPrompt
	local shopkeeper = getShopkeeperTemplate():Clone()
	shopkeeper.Name = "MergeShopkeeper"
	shopkeeper.Parent = workspace
	local part = shopkeeper.PrimaryPart
	assert(part, "MergeShopkeeperController requires shopkeeper.PrimaryPart to be configured")
	return createMergePrompt(part)
end
function MergeShopkeeperController:Init()
	MergeHud.gui.Parent = localPlayer:WaitForChild("PlayerGui")
	MergeHud.setGunSelectedCallback(selectGun)
	MergeHud.setMergeRequestedCallback(requestMerge)
	MergeHud.setCloseRequestedCallback(closeMergeHud)
end

function MergeShopkeeperController:Start()
	mergeInventoryUpdatedRemote = Framework.GetRemote("MergeInventoryUpdated")
	requestMergeInventoryRemote = Framework.GetRemote("RequestMergeInventory")
	mergeGunsRemote = Framework.GetRemote("MergeGuns")
	mergeResultRemote = Framework.GetRemote("MergeResult")
	Logger.onClientEvent(mergeInventoryUpdatedRemote, "MergeShopkeeperController", onMergeInventoryUpdated)
	Logger.onClientEvent(mergeResultRemote, "MergeShopkeeperController", onMergeResult)
	local prompt = spawnShopkeeper()
	prompt.Triggered:Connect(openMergeHud)
end

Framework.CreateController(MergeShopkeeperController)

return MergeShopkeeperController