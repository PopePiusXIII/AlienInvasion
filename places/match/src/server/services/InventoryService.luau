--!strict
--------------------------------------------------------------------------------
-- InventoryService.luau  (src/server/services)
-- Manages custom inventory system server-side, replacing native Roblox Backpack.
-- Tracks each player's weapon inventory and equipped slot.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local TAG = "InventoryService"

local InventoryService = Framework.CreateService({ Name = TAG })

-- Player inventory state: { [userId] = { weapons = { "M82", "Deagle" }, equippedSlot = 1 } }
local _playerInventories: { [number]: { weapons: { string }, equippedSlot: number? } } = {}

local _inventorySyncRemote:  RemoteEvent
local _inventoryEquipRemote: RemoteEvent

-- ── Weapon Helper Functions ──────────────────────────────────────────────────

local function findWeaponSource(gunName: string): Instance?
	local found = ServerStorage:FindFirstChild(gunName, true)
	if found and (found:IsA("Tool") or found:IsA("Model")) then
		return found
	end
	return nil
end

local function ensureHandle(tool: Tool): BasePart?
	local directHandle = tool:FindFirstChild("Handle")
	if directHandle and directHandle:IsA("BasePart") then
		return directHandle :: BasePart
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Name = "Handle"
			descendant.Parent = tool
			return descendant :: BasePart
		end
	end
	return nil
end

local function normalizeToolPhysics(tool: Tool)
	local handle = ensureHandle(tool)
	if not handle then return end

	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= handle then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
end

local function cloneWeaponAsTool(gunName: string): Tool?
	local source = findWeaponSource(gunName)
	if not source then return nil end

	if source:IsA("Tool") then
		local toolClone = (source :: Tool):Clone()
		normalizeToolPhysics(toolClone)
		return toolClone
	end

	if source:IsA("Model") then
		local tool = Instance.new("Tool")
		tool.Name = gunName
		tool.RequiresHandle = true
		local modelClone = (source :: Model):Clone()
		modelClone.Parent = tool
		normalizeToolPhysics(tool)
		return tool
	end
	return nil
end

-- ── Inventory Logic ──────────────────────────────────────────────────────────

local function getInventorySize(): number
	return Config.INVENTORY_SIZE or 2 -- [cite: 3]
end

local function getInventory(player: Player): { weapons: { string }, equippedSlot: number? }
	local uid = player.UserId -- [cite: 4]
	if not _playerInventories[uid] then
		_playerInventories[uid] = { weapons = {}, equippedSlot = nil } -- [cite: 4]
	end
	return _playerInventories[uid] -- [cite: 4]
end

local function syncToClient(player: Player)
	local inventory = getInventory(player) -- [cite: 4]
	_inventorySyncRemote:FireClient(player, inventory.weapons, inventory.equippedSlot) -- [cite: 4]
end

function InventoryService.addWeapon(player: Player, weaponName: string): boolean
	local inventory = getInventory(player) -- [cite: 4]
	local maxSize = getInventorySize() -- [cite: 3]
	
	for _, w in ipairs(inventory.weapons) do -- [cite: 5]
		if w == weaponName then return false end
	end
	
	if #inventory.weapons >= maxSize then return false end -- [cite: 5]
	
	table.insert(inventory.weapons, weaponName) -- [cite: 5]
	if #inventory.weapons == 1 then inventory.equippedSlot = 1 end -- [cite: 5]
	
	syncToClient(player) -- [cite: 5]
	return true
end

function InventoryService.removeWeapon(player: Player, weaponName: string): boolean
	local inventory = getInventory(player) -- [cite: 6]
	for i, w in ipairs(inventory.weapons) do
		if w == weaponName then
			table.remove(inventory.weapons, i) -- [cite: 6]
			if inventory.equippedSlot == i then
				inventory.equippedSlot = #inventory.weapons > 0 and 1 or nil -- [cite: 6]
			elseif inventory.equippedSlot and inventory.equippedSlot > i then
				inventory.equippedSlot = inventory.equippedSlot - 1 -- [cite: 6]
			end
			syncToClient(player) -- [cite: 6]
			return true
		end
	end
	return false
end

function InventoryService.setEquippedSlot(player: Player, slot: number?)
	local inventory = getInventory(player) -- [cite: 6]
	local character = player.Character
	
	-- Clear current tool
	if character then
		local currentTool = character:FindFirstChildOfClass("Tool")
		if currentTool then currentTool:Destroy() end
	end

	if slot == nil or slot < 1 or slot > #inventory.weapons then
		inventory.equippedSlot = nil -- [cite: 6]
		syncToClient(player) -- [cite: 6]
		return
	end

	inventory.equippedSlot = slot -- [cite: 6]
	
	-- Equip new tool
	local weaponName = inventory.weapons[slot]
	if character and weaponName then
		local tool = cloneWeaponAsTool(weaponName)
		if tool then tool.Parent = character end
	end

	syncToClient(player) -- [cite: 6]
end

function InventoryService.getEquippedWeapon(player: Player): string?
	local inventory = getInventory(player) -- [cite: 7]
	if inventory.equippedSlot and inventory.weapons[inventory.equippedSlot] then
		return inventory.weapons[inventory.equippedSlot] -- [cite: 7]
	end
	return nil
end

function InventoryService.getWeapons(player: Player): { string }
	return getInventory(player).weapons -- [cite: 7]
end

function InventoryService.clearInventory(player: Player)
	local uid = player.UserId -- [cite: 7]
	_playerInventories[uid] = { weapons = {}, equippedSlot = nil } -- [cite: 7]
	syncToClient(player) -- [cite: 7]
end

function InventoryService.replaceWeapon(player: Player, slot: number, newWeaponName: string): boolean
	local inventory = getInventory(player) -- [cite: 7]
	if slot < 1 or slot > #inventory.weapons then return false end -- [cite: 7]
	inventory.weapons[slot] = newWeaponName -- [cite: 7]
	syncToClient(player) -- [cite: 7]
	return true
end

function InventoryService.removeWeaponAtSlot(player: Player, slot: number): boolean
	local inventory = getInventory(player) -- [cite: 8]
	if slot < 1 or slot > #inventory.weapons then return false end -- [cite: 8]
	local weaponName = inventory.weapons[slot] -- [cite: 8]
	table.remove(inventory.weapons, slot) -- [cite: 8]
	
	if inventory.equippedSlot == slot then
		inventory.equippedSlot = #inventory.weapons > 0 and 1 or nil -- [cite: 8]
	elseif inventory.equippedSlot and inventory.equippedSlot > slot then
		inventory.equippedSlot = inventory.equippedSlot - 1 -- [cite: 8]
	end
	syncToClient(player) -- [cite: 8]
	return true
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function InventoryService:Init()
	_inventorySyncRemote  = Framework.CreateRemote(RemoteNames.INVENTORY_SYNC) -- [cite: 8]
	_inventoryEquipRemote = Framework.CreateRemote(RemoteNames.INVENTORY_EQUIP) -- [cite: 8]
end

local function grantStarterGunsToPlayer(player: Player)
	local starterGuns = Config.STARTER_GUNS or {} -- [cite: 9]
	for _, gunName in ipairs(starterGuns) do
		InventoryService.addWeapon(player, gunName) -- [cite: 9]
	end
	syncToClient(player) -- [cite: 9]
end

local function grantStarterGunsToAll()
	for _, player in ipairs(Players:GetPlayers()) do -- [cite: 10]
		grantStarterGunsToPlayer(player) -- [cite: 10]
	end
end

function InventoryService:Start()
	Logger.wrapServerEvent(_inventoryEquipRemote, TAG, function(player: Player, slot: number?) -- [cite: 10]
		InventoryService.setEquippedSlot(player, slot) -- [cite: 10]
	end)

	Players.PlayerRemoving:Connect(function(player: Player) -- [cite: 10]
		_playerInventories[player.UserId] = nil -- [cite: 10]
	end)

	grantStarterGunsToAll() -- [cite: 10]

	Players.PlayerAdded:Connect(function(player: Player) -- [cite: 10]
		task.wait(0.5)
		grantStarterGunsToPlayer(player) -- [cite: 10]
	end)
end

return InventoryService