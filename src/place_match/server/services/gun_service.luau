--!strict

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)
local InventoryService = require(server_script_service.match.services.inventory_service)
local Profile = require(server_script_service.common.services.profile_api)

local TAG = "GunService"

type AmmoState = {
	magazine: number,
	reserve: number,
	lastShotAt: number,
	reloading: boolean,
	reloadId: string?,
	reloadEndsAt: number?,
}

export type GunServiceApi = {
	Name: string,
	Init: (self: GunServiceApi) -> (),
	Start: (self: GunServiceApi) -> (),
	tryFire: (player: Player) -> boolean,
	requestReload: (player: Player) -> boolean,
	replenishEquippedAmmo: (player: Player) -> (),
}

local _ammoByPlayer: { [number]: { [string]: AmmoState } } = {}
local _ammoStateUpdatedRemote: RemoteEvent
local _requestGunReloadRemote: RemoteEvent
local _cancelGunReloadRemote: RemoteEvent

local function getGunStats(player: Player, gunId: string)
	local level = InventoryService.getGunLevel(player, gunId)
	local stats = Profile.GunApi.getGunStats(player, gunId, level)
	assert(stats, string.format("Missing stats for gun '%s' owned by %s", gunId, player.Name))
	return stats
end

local function getGunName(player: Player, gunId: string): string
	local gun = Profile.GunApi.getGun(player, gunId)
	assert(gun, string.format("Missing gun '%s' owned by %s", gunId, player.Name))
	return gun.name
end

local function getAmmoState(player: Player, gunId: string): AmmoState
	local states = _ammoByPlayer[player.UserId]
	if not states then
		states = {}
		_ammoByPlayer[player.UserId] = states
	end

	local state = states[gunId]
	if state then
		return state
	end

	local stats = getGunStats(player, gunId)
	local initialState: AmmoState = {
		magazine = stats.magSize,
		reserve = stats.max_ammo,
		lastShotAt = -math.huge,
		reloading = false,
	}
	states[gunId] = initialState
	return initialState
end

local function publishAmmoState(player: Player, gunId: string, state: AmmoState)
	Logger.fireClient(
		_ammoStateUpdatedRemote,
		player,
		getGunName(player, gunId),
		state.magazine,
		state.reserve,
		state.reloading,
		state.reloadId,
		state.reloadEndsAt
	)
end

local function completeReload(player: Player, gunId: string, reloadId: string)
	if not player.Parent then
		return
	end

	local states = _ammoByPlayer[player.UserId]
	local state = states and states[gunId]
	if not state or not state.reloading or state.reloadId ~= reloadId then
		return
	end

	local stats = getGunStats(player, gunId)
	local amountToLoad = math.min(stats.magSize - state.magazine, state.reserve)
	state.magazine += amountToLoad
	state.reserve -= amountToLoad
	state.reloading = false
	state.reloadId = nil
	state.reloadEndsAt = nil
	publishAmmoState(player, gunId, state)
	Logger.info(TAG, "Reload completed for %s: gun=%s duration=%.3f", player.Name, gunId, stats.reloadTime)
end

local function onPlayerRemoving(player: Player)
	_ammoByPlayer[player.UserId] = nil
end

local function tryFire(player: Player): boolean
	local gunId = InventoryService.getEquippedGunId(player)
	if not gunId then
		return false
	end

	local state = getAmmoState(player, gunId)
	local stats = getGunStats(player, gunId)
	local now = os.clock()
	if state.reloading or state.magazine <= 0 or now - state.lastShotAt < stats.fireCooldown then
		publishAmmoState(player, gunId, state)
		return false
	end

	state.magazine -= 1
	state.lastShotAt = now
	publishAmmoState(player, gunId, state)
	return true
end

local function requestReload(player: Player): boolean
	local gunId = InventoryService.getEquippedGunId(player)
	if not gunId then
		return false
	end

	local state = getAmmoState(player, gunId)
	local stats = getGunStats(player, gunId)
	if state.reloading or state.magazine >= stats.magSize or state.reserve <= 0 then
		publishAmmoState(player, gunId, state)
		return false
	end

	state.reloading = true
	local reloadId = HttpService:GenerateGUID(false)
	state.reloadId = reloadId
	state.reloadEndsAt = workspace:GetServerTimeNow() + stats.reloadTime
	publishAmmoState(player, gunId, state)
	Logger.info(TAG, "Reload accepted for %s: gun=%s duration=%.3f endsAt=%.3f", player.Name, gunId, stats.reloadTime, state.reloadEndsAt)
	task.delay(stats.reloadTime, completeReload, player, gunId, reloadId)
	return true
end

local function cancelReload(player: Player, reloadId: string): boolean
	local states = _ammoByPlayer[player.UserId]
	if not states then
		return false
	end

	for gunId, state in states do
		if state.reloading and state.reloadId == reloadId then
			state.reloading = false
			state.reloadId = nil
			state.reloadEndsAt = nil
			publishAmmoState(player, gunId, state)
			Logger.info(TAG, "Reload cancelled for %s: gun=%s", player.Name, gunId)
			return true
		end
	end

	return false
end

local function replenishEquippedAmmo(player: Player)
	local gunId = InventoryService.getEquippedGunId(player)
	if not gunId then
		return
	end

	local state = getAmmoState(player, gunId)
	local stats = getGunStats(player, gunId)
	state.magazine = stats.magSize
	state.reserve = stats.max_ammo
	state.reloading = false
	state.reloadId = nil
	state.reloadEndsAt = nil
	publishAmmoState(player, gunId, state)
end

local function onReloadRequested(player: Player)
	requestReload(player)
end

local function onReloadCancelled(player: Player, reloadId: string)
	cancelReload(player, reloadId)
end

local function initGunService(_self: GunServiceApi)
	_ammoStateUpdatedRemote = Framework.CreateRemote("AmmoStateUpdated")
	_requestGunReloadRemote = Framework.CreateRemote("RequestGunReload")
	_cancelGunReloadRemote = Framework.CreateRemote("CancelGunReload")
end

local function startGunService(_self: GunServiceApi)
	Logger.onServerEvent(_requestGunReloadRemote, TAG, onReloadRequested)
	Logger.onServerEvent(_cancelGunReloadRemote, TAG, onReloadCancelled)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

local GunService: GunServiceApi = {
	Name = TAG,
	Init = initGunService,
	Start = startGunService,
	tryFire = tryFire,
	requestReload = requestReload,
	replenishEquippedAmmo = replenishEquippedAmmo,
}

Framework.CreateService(GunService)
return GunService