--!strict

local Players = game:GetService("Players")

local replicated_storage = game:GetService("ReplicatedStorage")

local Framework = require(replicated_storage.common.shared.framework)
local Merge = require(replicated_storage.common.shared.vide.merge)

local MergeShopkeeperController = { Name = "MergeShopkeeperController" }

local localPlayer = assert(Players.LocalPlayer, "MergeShopkeeperController requires a local player")
local mergeGui: ScreenGui

local function closeMergeGui()
	mergeGui.Enabled = false
end

local function openMergeGui()
	mergeGui.Enabled = true
end

local function getShopkeeperTemplate(): Model
	local assets = replicated_storage:WaitForChild("assets")
	local stores = assets:WaitForChild("stores")
	local foundry = stores:WaitForChild("foundry")
	local shopkeeper = foundry:WaitForChild("shopkeeper")
	assert(shopkeeper:IsA("Model"), "MergeShopkeeperController requires ReplicatedStorage.assets.stores.foundry.shopkeeper to be a Model")
	return shopkeeper
end

local function createMergePrompt(interactionPart: BasePart): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MergePrompt"
	prompt.ActionText = "Merge"
	prompt.ObjectText = "Foundry"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = interactionPart
	return prompt
end

local function spawnShopkeeper(): ProximityPrompt
	local shopkeeper = getShopkeeperTemplate():Clone()
	shopkeeper.Name = "MergeShopkeeper"
	shopkeeper.Parent = workspace

	local interactionPart = shopkeeper.PrimaryPart
	assert(interactionPart, "MergeShopkeeperController requires shopkeeper.PrimaryPart to be configured")
	return createMergePrompt(interactionPart)
end

function MergeShopkeeperController:Init()
	mergeGui = Merge()
	mergeGui.Enabled = false
	mergeGui.ResetOnSpawn = false
	mergeGui.Parent = localPlayer:WaitForChild("PlayerGui")

	local closeButton = mergeGui:FindFirstChild("X_Button", true)
	assert(closeButton and closeButton:IsA("ImageButton"), "Merge UI requires an ImageButton named X_Button")
	closeButton.Activated:Connect(closeMergeGui)
end

function MergeShopkeeperController:Start()
	local mergePrompt = spawnShopkeeper()
	mergePrompt.Triggered:Connect(openMergeGui)
end

Framework.CreateController(MergeShopkeeperController)

return MergeShopkeeperController