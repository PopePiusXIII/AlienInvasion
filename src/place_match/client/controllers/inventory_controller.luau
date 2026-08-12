--!strict
--------------------------------------------------------------------------------
-- InventoryController.luau  (src/client/controllers)
-- Client-side inventory controller. Syncs with InventoryService on server.
-- Exposes API for other controllers to access inventory state.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")

local Framework     = require(replicated_storage.common.shared.framework)
local Logger        = require(replicated_storage.common.shared.logger)
local GunCore     = require(replicated_storage.common.shared.gun_core)

local TAG = "InventoryController"

local UserInputService = game:GetService("UserInputService")

local InventoryController = {}
InventoryController.Name = TAG

-- Disable default Roblox backpack UI (we use our custom inventory system)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local _localPlayer = Players.LocalPlayer

--- Synced gun: server-resolved stats + UUID + name for Tool matching.
export type SyncedGun = {
	id: string,
	name: string,
	stats: GunCore.Gun,
}

-- Local inventory state
local _guns: { SyncedGun } = {}
local _equippedSlot: number? = nil

-- Callbacks for when inventory changes
local _onInventoryChangedCallbacks: { (guns: { SyncedGun }, equippedSlot: number?) -> () } = {}

local _inventoryUpdatedRemote: RemoteEvent
local _equipInventorySlotRemote: RemoteEvent

--- Gets the current guns in the inventory (full synced data)
function InventoryController.getGuns(): { SyncedGun }
	if not _guns then
		return {} :: SyncedGun
	end

	return _guns
end
--- Checks if a weapon name exists in the inventory
function InventoryController.hasWeapon(name: string): boolean
	for _, g in ipairs(_guns) do
		if g.name == name then return true end
	end
	return false
end

--- Gets the equipped slot (1-indexed, nil if nothing equipped)
function InventoryController.getEquippedSlot(): number?
	return _equippedSlot
end

--- Gets the equipped gun's full synced data (nil if nothing equipped)
function InventoryController.getEquippedGun(): SyncedGun?
	if _equippedSlot and _guns[_equippedSlot] then
		return _guns[_equippedSlot]
	end
	return nil
end

--- Gets the equipped weapon's resolved stats (nil if nothing equipped)
function InventoryController.getEquippedStats(): GunCore.Gun?
	local gun = InventoryController.getEquippedGun()
	return gun and gun.stats or nil
end

--- Requests to equip a weapon at the given slot (1-indexed)
function InventoryController.equipSlot(slot: number?)
	_equipInventorySlotRemote:FireServer(slot)
end

--- Registers a callback to be invoked when inventory changes
function InventoryController.onInventoryChanged(callback: (guns: { SyncedGun }, equippedSlot: number?) -> ())
	table.insert(_onInventoryChangedCallbacks, callback)
end

--- Internal: updates local state and fires callbacks
local function updateInventory(guns: { SyncedGun }, equippedSlot: number?)
	_guns = guns
	_equippedSlot = equippedSlot
	
	Logger.info(TAG, "Inventory updated: %d guns, equipped slot: %s", 
		#guns, tostring(equippedSlot))
	
	-- Fire all callbacks
	for _, callback in ipairs(_onInventoryChangedCallbacks) do
		task.spawn(callback, guns, equippedSlot)
	end
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function InventoryController:Init()
	Logger.info(TAG, "Initialized.")
end

function InventoryController:Start()
	_inventoryUpdatedRemote = Framework.GetRemote("InventoryUpdated")
	_equipInventorySlotRemote = Framework.GetRemote("EquipInventorySlot")

	-- Listen for inventory updates from the server.
    Logger.info(TAG, "INVENTORY UPDATED REMOTE STARTED")
	Logger.onClientEvent(_inventoryUpdatedRemote, TAG, function(guns: { SyncedGun }, equippedSlot: number?)
		updateInventory(guns, equippedSlot)
	end)

	-- Input listener for equipping weapons
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.One then
			InventoryController.equipSlot(1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			InventoryController.equipSlot(2)
		end
	end)

	Logger.info(TAG, "Started. Listening for inventory sync and keybinds.")
end
Framework.CreateController(InventoryController)
return InventoryController
