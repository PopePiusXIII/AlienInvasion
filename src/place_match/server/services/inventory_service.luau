--!strict
--------------------------------------------------------------------------------
-- InventoryService.luau  (src/server/services)
-- Manages custom inventory system server-side, replacing native Roblox Backpack.
-- Profile-backed: gun instances live in ProfileService with UUIDs.
-- This service tracks in-match slot assignments and Tool cloning for equipping.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.common.shared.framework)
local Logger    = require(replicated_storage.common.shared.logger)
local CombatConfig    = require(replicated_storage.common.shared.configs.combat_config)
local GunCore = require(replicated_storage.common.shared.gun_core)
local commonServices = server_script_service:WaitForChild("common"):WaitForChild("services")
local Profile = require(commonServices:WaitForChild("profile_api"))

local TAG = "InventoryService"

local InventoryService = {}
InventoryService.Name = TAG

type GunInstance = GunCore.GunInstance

local _playerInventories: { [number]: { gunIds: { string }, equippedSlot: number? } } = {}
local _gunLevels: { [number]: { [string]: number } } = {}

local _inventoryUpdatedRemote: RemoteEvent
local _equipInventorySlotRemote: RemoteEvent

-- ── Weapon Helper Functions ──────────────────────────────────────────────────

local function findWeaponModel(gunName: string): Instance?
	local found = ServerStorage:FindFirstChild(gunName, true)
	if found and (found:IsA("Tool") or found:IsA("Model")) then
		return found
	end
	Logger.warn(TAG, "No weapon model found named %s", gunName)
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
	local source = findWeaponModel(gunName)
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
	-- needs to be filled out
	return 2
end

local function getInventory(player: Player): { gunIds: { string }, equippedSlot: number? }
	local uid = player.UserId
	if not _playerInventories[uid] then
		_playerInventories[uid] = { gunIds = {}, equippedSlot = nil }
	end
	return _playerInventories[uid]
end

--- Sync inventory state to client: sends resolved stats (server does the lookup).
local function syncToClient(player: Player)
	local inv = getInventory(player)
	local levels = _gunLevels[player.UserId] or {}

	-- Server resolves stats and sends them directly — client doesn't need rarity/level.
	local weaponData: { { id: string, name: string, rarity: string, stats: any } } = {}
	for _, gid in ipairs(inv.gunIds) do
		local instance = Profile.GunApi.getGun(player, gid)
		if instance then
			local resolved = Profile.GunApi.getGunStats(player, gid, levels[gid])
			if resolved then
				table.insert(weaponData, {
					id = gid,
					name = instance.name,
					rarity = instance.rarity,
					stats = resolved,
				})
			end
		end
	end

	Logger.fireClient(_inventoryUpdatedRemote, player, weaponData, inv.equippedSlot)
	Logger.info(TAG, "syncToClient %s — slots=%d, equippedSlot=%s",
		player.Name, #inv.gunIds, tostring(inv.equippedSlot))
end

--- Rebuild the two-slot in-match inventory from the player's profile.
local function syncFromProfile(player: Player): number
	local profileInventory = Profile.GunApi.getInventory(player)
	if not profileInventory then return 0 end

	local inv = getInventory(player)
	inv.gunIds = {}
	local maxSize = getInventorySize()
	local candidates: { GunInstance } = table.clone(profileInventory)
	table.sort(candidates, function(left: GunInstance, right: GunInstance): boolean
		if left.name == right.name then
			return left.id < right.id
		end
		return left.name < right.name
	end)

	local selectedIds: { [string]: boolean } = {}
	local selectedFamilies: { [string]: boolean } = {}
	local function selectGun(instance: GunInstance)
		if #inv.gunIds >= maxSize or selectedIds[instance.id] then return end
		table.insert(inv.gunIds, instance.id)
		selectedIds[instance.id] = true
		selectedFamilies[instance.name] = true
	end

	-- A profile is UUID-keyed, so use configured starters rather than table order.
	for _, starterGun in ipairs(CombatConfig.STARTER_GUNS) do
		for _, instance in ipairs(candidates) do
			if instance.name == starterGun.name and instance.rarity == starterGun.rarity then
				selectGun(instance)
				break
			end
		end
	end

	-- Fill open slots with one instance of each remaining gun family.
	for _, instance in ipairs(candidates) do
		if #inv.gunIds >= maxSize then break end
		if not selectedFamilies[instance.name] then
			selectGun(instance)
		end
	end
	inv.equippedSlot = #inv.gunIds > 0 and 1 or nil

	-- Reset all levels to 1 for this match
	_playerInventories[player.UserId] = inv
	_gunLevels[player.UserId] = {}
	for _, gid in ipairs(inv.gunIds) do
		_gunLevels[player.UserId][gid] = 1
	end

	syncToClient(player)
	return #profileInventory
end

--- Add a gun to the player's inventory.
--- First grants it via ProfileService (creates the persistent instance), then adds to in-match slots.
function InventoryService.addWeapon(player: Player, gunName: string, rarity: string): boolean
	local inv = getInventory(player)
	local maxSize = getInventorySize()

	if #inv.gunIds >= maxSize then return false end

	-- Grant via profile (returns new gun ID or nil if already owned / error)
	local gunId = Profile.GunApi.grantGun(player, gunName, rarity)
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
function InventoryService.addWeaponAtSlot(player: Player, gunName: string, rarity: string, slot: number): boolean
	local inv = getInventory(player)
	local maxSize = getInventorySize()

	if #inv.gunIds >= maxSize then return false end

	local gunId = Profile.GunApi.grantGun(player, gunName, rarity)
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
	local instance = Profile.GunApi.getGun(player, gunId)
    if character and instance then
        local tool = cloneWeaponAsTool(instance.name)
        if tool then
			tool.Name = instance.name
			tool.Parent = player.Backpack
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:EquipTool(tool)
			else
				tool.Parent = character
			end
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
	local levels = _gunLevels[player.UserId]
	if not levels then return 1 end
	return levels[gunId] or 1
end

--- Upgrade a gun's in-memory level (1->2->3->4). Returns (success, newLevel?, reason?).
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
	local ok, _, errMsg = Profile.GunApi.upgradeLevel(player, gunId)
	if not ok then
		levels[gunId] = current -- Rollback
		return false, nil, errMsg or "PROFILE_ERROR"
	end

	syncToClient(player)
	return true, levels[gunId], nil
end

--- Get all gun IDs in the player's inventory.
function InventoryService.getGunIds(player: Player): { string }
	return getInventory(player).gunIds
end

function InventoryService.clearInventory(player: Player)
	local uid = player.UserId
	_playerInventories[uid] = { gunIds = {}, equippedSlot = nil }
	syncToClient(player)
end

function InventoryService.replaceWeapon(player: Player, slot: number, newWeaponName: string, rarity: string): boolean
	local inv = getInventory(player)
	if slot < 1 or slot > #inv.gunIds then return false end

	-- Remove old gun from profile
	local oldGunId = inv.gunIds[slot]
	local oldInstance = Profile.GunApi.getGun(player, oldGunId)
	if oldInstance then
			Profile.GunApi.removeGun(player, oldGunId)
	end

	-- Grant new gun via profile
	local newGunId = Profile.GunApi.grantGun(player, newWeaponName, rarity)
	if not newGunId then return false end

	inv.gunIds[slot] = newGunId
	syncToClient(player)
	return true
end

function InventoryService.removeWeaponAtSlot(player: Player, slot: number): boolean
	local inv = getInventory(player)
	if slot < 1 or slot > #inv.gunIds then return false end

	local gunId = inv.gunIds[slot]
	Profile.GunApi.removeGun(player, gunId)
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
	_inventoryUpdatedRemote = Framework.CreateRemote("InventoryUpdated")
	_equipInventorySlotRemote = Framework.CreateRemote("EquipInventorySlot")
end

local function grantStarterGunsToPlayer(player: Player)
	-- Persistent ownership is independent of the two-slot match hotbar.
	local profileGunCount = syncFromProfile(player)

	-- Grant starters only for a first-time profile, not for a full match hotbar.
	if profileGunCount == 0 then
		for _, starterGun in ipairs(CombatConfig.STARTER_GUNS) do
			InventoryService.addWeapon(player, starterGun.name, starterGun.rarity)
		end
		syncToClient(player)
	end
end

function InventoryService:Start()
	Logger.onServerEvent(_equipInventorySlotRemote, TAG, function(player: Player, slot: number?)
		InventoryService.setEquippedSlot(player, slot)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		_playerInventories[player.UserId] = nil
		_gunLevels[player.UserId] = nil
	end)

	Profile.Db.OnProfileLoaded(function(player, profile)
		grantStarterGunsToPlayer(player)
	end)

end

 Framework.CreateService(InventoryService)


return InventoryService
