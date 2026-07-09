--!strict
--------------------------------------------------------------------------------
-- RNGService.luau  (src/server/services)
-- Handles RNG block activation and weapon granting.
-- Responsibilities: destroy RNG block, send unlocked list, process weapon swaps.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework     = require(ReplicatedStorage.Shared.Framework)
local Logger        = require(ReplicatedStorage.Shared.Logger)
local Config        = require(ReplicatedStorage.Shared.Config)
local RemoteNames   = require(ReplicatedStorage.Shared.RemoteNames)
local ProfileService = require(ReplicatedStorage.Shared.ProfileService)

local TAG = "RNGService"
local RNGService = Framework.CreateService({ Name = TAG })

-- ── State ────────────────────────────────────────────────────────────────────

local _rngActivateRemote:     RemoteEvent
local _rngUnlockedListRemote: RemoteEvent
local _rngRequestGiveRemote:  RemoteEvent
local _rngTopupRemote:        RemoteEvent
local _playerLocks:           { [number]: boolean } = {}
local _lastActivateTime:      { [number]: number }  = {}

-- Lazy-loaded to avoid circular dependency.
local InventoryService = nil

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function ensureInventoryService()
	if not InventoryService then
		InventoryService = Framework.GetService("InventoryService")
	end
end

local function isValidWeapon(weaponName: string): boolean
	return Config.GUN_STATS[weaponName] ~= nil
end

local function playerOwnsWeapon(player: Player, weaponName: string): boolean
	if ProfileService.isWeaponUnlocked(player, weaponName) then
		return true
	end
	ensureInventoryService()
	local currentWeapons = InventoryService.getWeapons(player)
	for _, w in ipairs(currentWeapons) do
		if w == weaponName then return true end
	end
	return false
end

local function topUpEquippedAmmo(player: Player, weaponName: string)
	local stats = Config.GUN_STATS[weaponName]
	if not stats then return end
	Logger.info(TAG, "Rolled weapon matches equipped (%s) for %s — topping up ammo.", weaponName, player.Name)
	_rngTopupRemote:FireClient(player, weaponName, stats.magSize, stats.max_ammo)
end

local function removeWeaponForSwap(player: Player, slotIndex: number, toRemoveName: string?)
	local currentWeapons = InventoryService.getWeapons(player)
	if slotIndex < 1 or slotIndex > #currentWeapons then return end

	local toRemove = toRemoveName
	if not toRemove or toRemove == "" then
		toRemove = currentWeapons[slotIndex]
	end

	if toRemove and toRemove ~= "" then
		Logger.info(TAG, "Removing weapon %s from slot %d for %s", toRemove, slotIndex, player.Name)
		InventoryService.removeWeapon(player, toRemove)
	end
end

local function grantAndEquipWeapon(player: Player, weaponName: string, slotIndex: number)
	local success = InventoryService.addWeaponAtSlot(player, weaponName, slotIndex)
	if not success then
		Logger.warn(TAG, "Failed to add %s to inventory for %s", weaponName, player.Name)
		return
	end
	Logger.info(TAG, "Added %s to inventory for %s via RNG at slot %d", weaponName, player.Name, slotIndex)

	-- Find the actual index of the newly added weapon and equip it.
	local newWeapons = InventoryService.getWeapons(player)
	for i, w in ipairs(newWeapons) do
		if w == weaponName then
			InventoryService.setEquippedSlot(player, i)
			break
		end
	end
end

--- Runs a function with a per-player lock; guarantees unlock even on error.
local function withPlayerLock(uid: number, fn: () -> ())
	if _playerLocks[uid] then return end
	_playerLocks[uid] = true
	local ok, err = pcall(fn)
	_playerLocks[uid] = nil
	if not ok then
		Logger.warn(TAG, "pcall failed: %s", tostring(err))
	end
end

local function getPlayerUnlockedList(player: Player): { string }
	local unlocked: { string } = {}
	for gunName, _ in pairs(Config.GUN_STATS :: GunModule.GunCatalog) do
		if ProfileService.isWeaponUnlocked(player, gunName) then
			table.insert(unlocked, gunName)
		end
	end

	return unlocked
end

-- ── Remote Handlers ──────────────────────────────────────────────────────────

local function handleRngActivate(player: Player)
	local uid = player.UserId
	local now = tick()
	local last = _lastActivateTime[uid]
	if last and now - last < 0.000001 then
		Logger.info(TAG, "Ignoring duplicate RNG_ACTIVATE from %s (cooldown)", player.Name)
		return
	end
	_lastActivateTime[uid] = now

	-- Destroy the RNG block in workspace.
	local rngPart = workspace:FindFirstChild("RNG BLOCK", true)
	if rngPart then
		rngPart:Destroy()
		Logger.info(TAG, "Destroyed RNG BLOCK for %s", player.Name)
	else
		Logger.info(TAG, "No RNG BLOCK found to destroy for %s", player.Name)
	end

	local unlocked = getPlayerUnlockedList(player)
	Logger.info(TAG, "Sending unlocked list (count=%d) to %s", #unlocked, player.Name)
	_rngUnlockedListRemote:FireClient(player, unlocked)

    if #unlocked == 0 then
        Logger.warn("no guns unlocked for player %s", player.Name)
    end
end

local function handleRngRequestGive(player: Player, weaponName: string, slotIndex: number, toRemoveName: string?)
	if type(weaponName) ~= "string" then return end
	if not isValidWeapon(weaponName) then return end
	if not playerOwnsWeapon(player, weaponName) then
		Logger.warn(TAG, "Rejecting RNG grant of %s for %s — not unlocked nor owned.", weaponName, player.Name)
		return
	end

	ensureInventoryService() --need to fix this FIX!!!

	local uid = player.UserId
	withPlayerLock(uid, function()
		local equippedWeapon = InventoryService.getEquippedWeapon(player)

		Logger.info(TAG, "Server current inventory for %s — weapons=%s, equipped=%s",
			player.Name, table.concat(InventoryService.getWeapons(player), ", "), tostring(equippedWeapon))

		-- If the rolled weapon is already equipped, just top up ammo.
		if equippedWeapon == weaponName then
			topUpEquippedAmmo(player, weaponName)
			return
		end

		removeWeaponForSwap(player, slotIndex, toRemoveName)
		grantAndEquipWeapon(player, weaponName, slotIndex)
	end)
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────

function RNGService:Init()
	_rngActivateRemote     = Framework.CreateRemote(RemoteNames.RNG_ACTIVATE)
	_rngUnlockedListRemote = Framework.CreateRemote(RemoteNames.RNG_UNLOCKED_LIST)
	_rngRequestGiveRemote  = Framework.CreateRemote(RemoteNames.RNG_REQUEST_GIVE)
	_rngTopupRemote        = Framework.CreateRemote(RemoteNames.RNG_TOPUP_AMMO)
end

function RNGService:Start()
	_rngActivateRemote.OnServerEvent:Connect(handleRngActivate)
	_rngRequestGiveRemote.OnServerEvent:Connect(handleRngRequestGive)
end

return RNGService
