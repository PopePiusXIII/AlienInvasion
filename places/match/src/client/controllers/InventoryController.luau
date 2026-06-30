--!strict
--------------------------------------------------------------------------------
-- InventoryController.luau  (src/client/controllers)
-- Client-side inventory controller. Syncs with InventoryService on server.
-- Exposes API for other controllers to access inventory state.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework     = require(ReplicatedStorage.Shared.Framework)
local Logger        = require(ReplicatedStorage.Shared.Logger)
local RemoteNames   = require(ReplicatedStorage.Shared.RemoteNames)

local TAG = "InventoryController"

local UserInputService = game:GetService("UserInputService")
local InventoryController = Framework.CreateController({ Name = TAG })

local _localPlayer = Players.LocalPlayer

-- Local inventory state
local _weapons: { string } = {}
local _equippedSlot: number? = nil

-- Callbacks for when inventory changes
local _onInventoryChangedCallbacks: { (weapons: { string }, equippedSlot: number?) -> () } = {}

local _inventorySyncRemote:  RemoteEvent
local _inventoryEquipRemote: RemoteEvent

--- Gets the current weapons in the inventory
function InventoryController.getWeapons(): { string }
	return _weapons
end

--- Gets the equipped slot (1-indexed, nil if nothing equipped)
function InventoryController.getEquippedSlot(): number?
	return _equippedSlot
end

--- Gets the equipped weapon name (nil if nothing equipped)
function InventoryController.getEquippedWeapon(): string?
	if _equippedSlot and _weapons[_equippedSlot] then
		return _weapons[_equippedSlot]
	end
	return nil
end

--- Requests to equip a weapon at the given slot (1-indexed)
function InventoryController.equipSlot(slot: number?)
	_inventoryEquipRemote:FireServer(slot)
end

--- Registers a callback to be invoked when inventory changes
function InventoryController.onInventoryChanged(callback: (weapons: { string }, equippedSlot: number?) -> ())
	table.insert(_onInventoryChangedCallbacks, callback)
end

--- Internal: updates local state and fires callbacks
local function updateInventory(weapons: { string }, equippedSlot: number?)
	_weapons = weapons
	_equippedSlot = equippedSlot
	
	Logger.info(TAG, "Inventory updated: %s, equipped slot: %s", 
		table.concat(weapons, ", "), tostring(equippedSlot))
	
	-- Fire all callbacks
	for _, callback in ipairs(_onInventoryChangedCallbacks) do
		task.spawn(callback, weapons, equippedSlot)
	end
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function InventoryController:Init()
	_inventorySyncRemote  = Framework.GetRemote(RemoteNames.INVENTORY_SYNC)
	_inventoryEquipRemote = Framework.GetRemote(RemoteNames.INVENTORY_EQUIP)

	Logger.info(TAG, "Initialized.")
end

function InventoryController:Start()
	-- Listen for inventory sync from server
    warn(TAG, "INVETORY SYNC REMOTE STARTED")
	Logger.wrapClientEvent(_inventorySyncRemote, TAG, function(weapons: { string }, equippedSlot: number?)
		updateInventory(weapons, equippedSlot)
	end)

	-- Input listener for equipping weapons
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		Logger.info(TAG, "11111111111111111111111111111111111111111")
        if gameProcessed then return end
		Logger.info(TAG, "222222222222222222222222222222222222222")
		if input.KeyCode == Enum.KeyCode.One then
			InventoryController.equipSlot(1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			InventoryController.equipSlot(2)
		end
	end)

	Logger.info(TAG, "Started. Listening for inventory sync and keybinds.")
end

return InventoryController
