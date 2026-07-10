--!strict
--------------------------------------------------------------------------------
-- InventoryService.luau  (src/server/services)
-- Manages custom inventory system server-side, replacing native Roblox Backpack.
-- Profile-backed: gun instances live in ProfileService with UUIDs.
-- This service tracks in-match slot assignments and Tool cloning for equipping.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local ProfileService = require(ReplicatedStorage.Shared.ProfileService)

local TAG = "InventoryService"

local InventoryService = Framework.CreateService({ Name = TAG })

-- In-match slot state: { [userId] = { gunIds = { "gun_1", "gun_2" }, equippedSlot = 1 } }
local _playerInventories: { [number]: { gunIds: { string }, equippedSlot: number? } } = {}

-- In-memory level tracking (resets each match, not persisted to profile).
-- { [userId] = { [gunId] = level (1-4) } }
local _gunLevels: { [number]: { [string]: number } } = {}

local _inventorySyncRemote:  RemoteEvent
local _inventoryEquipRemote: RemoteEvent

-- ── Weapon Helper Functions ──────────────────────────────────────────────────

--- Find a Tool/Model in ServerStorage by base gun name (e.g. "1911", not "rare_1911").
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
	return Config.INVENTORY_SIZE or 2
end

local function getInventory(player: Player): { gunIds: { string }, equippedSlot: number? }
	local uid = player.UserId
	if not _playerInventories[uid] then
		_playerInventories[uid] = { gunIds = {}, equippedSlot = nil }
	end
	return _playerInventories[uid]
end

--- Sync inventory state to client: sends gun IDs + metadata for HUD rendering.
local function syncToClient(player: Player)
	local inv = getInventory(player)
	local levels = _gunLevels[player.UserId] or {}

	-- Build enriched list with rarity/level for each slot
	local weaponData: { { id: string, name: string, rarity: string, level: number } } = {}
	for _, gid in ipairs(inv.gunIds) do
		local instance = ProfileService.getGun(player, gid)
		if instance then
			table.insert(weaponData, {
				id = instance.id,
				name = instance.name,
				rarity = instance.rarity,
				level = levels[gid] or 1,
			})
		end
	end

	Logger.fireClient(_inventorySyncRemote, player, weaponData, inv.equippedSlot)
	Logger.info(TAG, "syncToClient %s — slots=%d, equippedSlot=%s",
		player.Name, #inv.gunIds, tostring(inv.equippedSlot))
end

--- Rebuild in-match inventory from the player's profile.
local function syncFromProfile(player: Player)
	local profileInventory = ProfileService.getInventory(player)
	if not profileInventory then return end

	local inv = getInventory(player)
	inv.gunIds = {}
	for _, instance in ipairs(profileInventory) do
		table.insert(inv.gunIds, instance.id)
	end
	inv.equippedSlot = #inv.gunIds > 0 and 1 or nil

	-- Reset all levels to 1 for this match
	_playerInventories[player.UserId] = inv
	_gunLevels[player.UserId] = {}
	for _, gid in ipairs(inv.gunIds) do
		_gunLevels[player.UserId][gid] = 1
	end

	syncToClient(player)
end

--- Add a gun to the player's inventory.
--- First grants it via ProfileService (creates the persistent instance), then adds to in-match slots.
function InventoryService.addWeapon(player: Player, gunName: string): boolean
	local inv = getInventory(player)
	local maxSize = getInventorySize()

	if #inv.gunIds >= maxSize then return false end

	-- Grant via profile (returns new gun ID or nil if already owned / error)
	local gunId = ProfileService.grantGun(player, gunName)
	if not gunId then return false end

	table.insert(inv.gunIds, gunId)
	if #inv.gunIds == 1 then inv.equippedSlot = 1 end

	-- Initialize level to 1
	local uid = player.UserId
	if not _gunLevels[uid] then _gunLevels[uid] = {} end
	_gunLevels[uid][gunId] = 1

	syncToClient(player)
	return true
end

--- Add a weapon at a specific slot. Use -1 to append to the end.
function InventoryService.addWeaponAtSlot(player: Player, gunName: string, slot: number): boolean
	local inv = getInventory(player)
	local maxSize = getInventorySize()

	if #inv.gunIds >= maxSize then return false end

	local gunId = ProfileService.grantGun(player, gunName)
	if not gunId then return false end

	if slot == -1 then
		table.insert(inv.gunIds, gunId)
	else
		if slot < 1 or slot > #inv.gunIds + 1 then return false end
		table.insert(inv.gunIds, slot, gunId)
	end

	if inv.equippedSlot and slot ~= -1 then
		if inv.equippedSlot >= slot then
			inv.equippedSlot = inv.equippedSlot + 1
		end
	elseif #inv.gunIds == 1 then
		inv.equippedSlot = 1
	end

	syncToClient(player)
	return true
end

--- Remove a gun by its profile ID (UUID).
function InventoryService.removeWeaponById(player: Player, gunId: string): boolean
	local inv = getInventory(player)
	for i, gid in ipairs(inv.gunIds) do
		if gid == gunId then
			table.remove(inv.gunIds, i)
			if inv.equippedSlot == i then
				inv.equippedSlot = #inv.gunIds > 0 and 1 or nil
			elseif inv.equippedSlot and inv.equippedSlot > i then
				inv.equippedSlot = inv.equippedSlot - 1
			end
			syncToClient(player)
			return true
		end
	end
	return false
end

--- Remove a gun by base name (legacy, removes first match).
function InventoryService.removeWeapon(player: Player, weaponName: string): boolean
	local inv = getInventory(player)
	for i, gid in ipairs(inv.gunIds) do
		local instance = ProfileService.getGun(player, gid)
		if instance and instance.name == weaponName then
			table.remove(inv.gunIds, i)
			ProfileService.removeGun(player, gid)

			if inv.equippedSlot == i then
				inv.equippedSlot = #inv.gunIds > 0 and 1 or nil
			elseif inv.equippedSlot and inv.equippedSlot > i then
				inv.equippedSlot = inv.equippedSlot - 1
			end
			syncToClient(player)
			return true
		end
	end
	return false
end

function InventoryService.setEquippedSlot(player: Player, slot: number?)
    local inv = getInventory(player)
    local character = player.Character

    -- Clear current tool from character
    if character then
        local currentTool = character:FindFirstChildOfClass("Tool")
        if currentTool then currentTool:Destroy() end
    end

    -- Clear all tools from backpack (we manage inventory ourselves)
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            tool:Destroy()
        end
    end

    if slot == nil or slot < 1 or slot > #inv.gunIds then
        inv.equippedSlot = nil
        syncToClient(player)
        return
    end

    inv.equippedSlot = slot

    -- Equip new tool (clone by base gun name from ServerStorage)
    local gunId = inv.gunIds[slot]
    local instance = ProfileService.getGun(player, gunId)
    if character and instance then
        local tool = cloneWeaponAsTool(instance.name)
        if tool then
			tool.Name = instance.name
            tool.Parent = character
        end
    end

    syncToClient(player)
end

--- Get the equipped gun's profile ID (UUID).
function InventoryService.getEquippedGunId(player: Player): string?
	local inv = getInventory(player)
	if inv.equippedSlot and inv.gunIds[inv.equippedSlot] then
		return inv.gunIds[inv.equippedSlot]
	end
	return nil
end

--- Get the in-memory level for a gun (1-4, resets each match).
function InventoryService.getGunLevel(player: Player, gunId: string): number
	local uid = player.UserId
	local levels = _gunLevels[uid]
	if not levels then return 1 end
	return levels[gunId] or 1
end

--- Upgrade a gun's in-memory level (1→2→3→4). Returns (success, newLevel?, reason?).
function InventoryService.upgradeGunLevel(player: Player, gunId: string): (boolean, number?, string?)
	local uid = player.UserId
	local levels = _gunLevels[uid]
	if not levels then return false, nil, "NO_LEVELS" end

	local current = levels[gunId] or 1
	if current >= 4 then
		return false, nil, "MAX_LEVEL"
	end

	levels[gunId] = current + 1

	-- Validate via ProfileService (ownership check)
	local ok, _, errMsg = ProfileService.upgradeLevel(player, gunId)
	if not ok then
		levels[gunId] = current -- Rollback
		return false, nil, errMsg or "PROFILE_ERROR"
	end

	syncToClient(player)
	return true, levels[gunId], nil
end

--- Get the equipped weapon's base name (legacy compat).
function InventoryService.getEquippedWeapon(player: Player): string?
	local gunId = InventoryService.getEquippedGunId(player)
	if not gunId then return nil end
	local instance = ProfileService.getGun(player, gunId)
	return instance and instance.name or nil
end

--- Get all gun IDs in the player's inventory.
function InventoryService.getGunIds(player: Player): { string }
	return getInventory(player).gunIds
end

--- Get all weapon base names (legacy compat for services that still expect names).
function InventoryService.getWeapons(player: Player): { string }
	local inv = getInventory(player)
	local names: { string } = {}
	for _, gid in ipairs(inv.gunIds) do
		local instance = ProfileService.getGun(player, gid)
		if instance then
			table.insert(names, instance.name)
		end
	end
	return names
end

function InventoryService.clearInventory(player: Player)
	local uid = player.UserId
	_playerInventories[uid] = { gunIds = {}, equippedSlot = nil }
	syncToClient(player)
end

function InventoryService.replaceWeapon(player: Player, slot: number, newWeaponName: string): boolean
	local inv = getInventory(player)
	if slot < 1 or slot > #inv.gunIds then return false end

	-- Remove old gun from profile
	local oldGunId = inv.gunIds[slot]
	local oldInstance = ProfileService.getGun(player, oldGunId)
	if oldInstance then
		ProfileService.removeGun(player, oldGunId)
	end

	-- Grant new gun via profile
	local newGunId = ProfileService.grantGun(player, newWeaponName)
	if not newGunId then return false end

	inv.gunIds[slot] = newGunId
	syncToClient(player)
	return true
end

function InventoryService.removeWeaponAtSlot(player: Player, slot: number): boolean
	local inv = getInventory(player)
	if slot < 1 or slot > #inv.gunIds then return false end

	local gunId = inv.gunIds[slot]
	ProfileService.removeGun(player, gunId)
	table.remove(inv.gunIds, slot)

	if inv.equippedSlot == slot then
		inv.equippedSlot = #inv.gunIds > 0 and 1 or nil
	elseif inv.equippedSlot and inv.equippedSlot > slot then
		inv.equippedSlot = inv.equippedSlot - 1
	end
	syncToClient(player)
	return true
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function InventoryService:Init()
	_inventorySyncRemote  = Framework.CreateRemote(RemoteNames.INVENTORY_SYNC)
	_inventoryEquipRemote = Framework.CreateRemote(RemoteNames.INVENTORY_EQUIP)
end

local function grantStarterGunsToPlayer(player: Player)
	-- Sync from profile first (restores persistent inventory)
	syncFromProfile(player)

	-- Grant starter guns if inventory is empty (first-time player)
	local inv = getInventory(player)
	if #inv.gunIds == 0 then
		local starterGuns = Config.STARTER_GUNS or {}
		for _, gunName in ipairs(starterGuns) do
			InventoryService.addWeapon(player, gunName)
		end
		syncToClient(player)
	end
end

local function grantStarterGunsToAll()
	for _, player in ipairs(Players:GetPlayers()) do
		grantStarterGunsToPlayer(player)
	end
end

function InventoryService:Start()
	Logger.wrapServerEvent(_inventoryEquipRemote, TAG, function(player: Player, slot: number?)
		InventoryService.setEquippedSlot(player, slot)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		_playerInventories[player.UserId] = nil
		_gunLevels[player.UserId] = nil
	end)

	grantStarterGunsToAll()

	Players.PlayerAdded:Connect(function(player: Player)
		task.wait(0.5)
		grantStarterGunsToPlayer(player)
	end)
end

return InventoryService