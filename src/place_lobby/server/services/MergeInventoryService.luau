--!strict
--------------------------------------------------------------------------------
-- MergeInventoryService.luau  (places/lobby/src/server/services)
-- Owns: merge inventory remotes, inventory synchronization, and gun merges.
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)
local ProfileApi = require(server_script_service.common.services.profile_api)

local TAG = "MergeInventoryService"

type MergeInventoryItem = {
	id: string,
	name: string,
	rarity: string,
	image: string,
}

local MergeInventoryService = { Name = "MergeInventoryService" }

local mergeInventoryUpdatedRemote: RemoteEvent
local requestMergeInventoryRemote: RemoteEvent
local mergeGunsRemote: RemoteEvent
local mergeResultRemote: RemoteEvent

local function sortMergeInventory(left: MergeInventoryItem, right: MergeInventoryItem): boolean
	if left.name == right.name then
		if left.rarity == right.rarity then
			return left.id < right.id
		end
		return left.rarity < right.rarity
	end
	return left.name < right.name
end

local function containsDuplicateGunIds(gunIds: { string }): boolean
	local seenGunIds: { [string]: boolean } = {}
	for _, gunId in ipairs(gunIds) do
		if seenGunIds[gunId] then
			return true
		end
		seenGunIds[gunId] = true
	end
	return false
end

function MergeInventoryService.sendInventory(player: Player)
	local inventory = assert(ProfileApi.GunApi.getInventory(player), "Cannot send merge inventory before the player profile loads")
	local items: { MergeInventoryItem } = {}

	for _, gun in ipairs(inventory) do
		local stats = assert(ProfileApi.GunApi.getGunStats(player, gun.id), "Merge inventory gun is missing configured stats: " .. gun.id)
		local image = assert(stats.image, "Merge inventory gun is missing an image: " .. gun.id)
		table.insert(items, {
			id = gun.id,
			name = gun.name,
			rarity = gun.rarity,
			image = image,
		})
	end

	table.sort(items, sortMergeInventory)
	Logger.fireClient(mergeInventoryUpdatedRemote, player, items)
end

function MergeInventoryService.onInventoryRequested(player: Player)
	MergeInventoryService.sendInventory(player)
end

function MergeInventoryService.onMergeGunsRequested(player: Player, gunIds: { string })
	if #gunIds ~= 3 or containsDuplicateGunIds(gunIds) then
		Logger.fireClient(mergeResultRemote, player, false, "INVALID_SELECTION")
		return
	end

	local succeeded, _, reason = ProfileApi.GunApi.mergeGuns(player, gunIds)
	if not succeeded then
		Logger.fireClient(mergeResultRemote, player, false, assert(reason, "GunApi merge failure must include a reason"))
		return
	end

	MergeInventoryService.sendInventory(player)
	Logger.fireClient(mergeResultRemote, player, true, "MERGE_COMPLETE")
end

function MergeInventoryService:Init()
	mergeInventoryUpdatedRemote = Framework.CreateRemote("MergeInventoryUpdated")
	requestMergeInventoryRemote = Framework.CreateRemote("RequestMergeInventory")
	mergeGunsRemote = Framework.CreateRemote("MergeGuns")
	mergeResultRemote = Framework.CreateRemote("MergeResult")

	ProfileApi.Db.OnProfileLoaded(MergeInventoryService.sendInventory)
	Logger.onServerEvent(requestMergeInventoryRemote, TAG, MergeInventoryService.onInventoryRequested)
	Logger.onServerEvent(mergeGunsRemote, TAG, MergeInventoryService.onMergeGunsRequested)
end

Framework.CreateService(MergeInventoryService)

return MergeInventoryService