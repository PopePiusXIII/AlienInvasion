--!strict
--------------------------------------------------------------------------------
-- LobbyServerRuntime.server.luau  (places/lobby/src/server)
-- THE single server entry point for the Lobby Place.
-- Requires all Lobby services and starts the framework.
-- NO game logic here — belongs in the appropriate service.
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.common.shared.framework)
local Logger    = require(replicated_storage.common.shared.logger)
local ProfileApi = require(server_script_service.common.services.profile_api)

-- ── Shared services (cross-place) ────────────────────────────────────────────
local ProfileDb = require(server_script_service.common.services.profile_db)

local currencyUpdatedRemote = Framework.CreateRemote("LobbyCurrencyUpdated")
local mergeInventoryUpdatedRemote = Framework.CreateRemote("MergeInventoryUpdated")
local requestMergeInventoryRemote = Framework.CreateRemote("RequestMergeInventory")
local mergeGunsRemote = Framework.CreateRemote("MergeGuns")
local mergeResultRemote = Framework.CreateRemote("MergeResult")

type MergeInventoryItem = {
	id: string,
	name: string,
	rarity: string,
	image: string,
}

local function sendCurrencyUpdated(player: Player, profile: any)
	local silverAmount = profile.lifetimeSilverEarned - profile.lifetimeSilverSpent
	Logger.fireClient(currencyUpdatedRemote, player, silverAmount, profile.goldStuds)
end

local function sortMergeInventory(left: MergeInventoryItem, right: MergeInventoryItem): boolean
	if left.name == right.name then
		if left.rarity == right.rarity then
			return left.id < right.id
		end
		return left.rarity < right.rarity
	end
	return left.name < right.name
end

local function sendMergeInventory(player: Player)
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

local function onMergeInventoryRequested(player: Player)
	sendMergeInventory(player)
end

local function onMergeGunsRequested(player: Player, gunIds: { string })
	if #gunIds ~= 3 or containsDuplicateGunIds(gunIds) then
		Logger.fireClient(mergeResultRemote, player, false, "INVALID_SELECTION")
		return
	end

	local succeeded, _, reason = ProfileApi.GunApi.mergeGuns(player, gunIds)
	if not succeeded then
		Logger.fireClient(mergeResultRemote, player, false, assert(reason, "GunApi merge failure must include a reason"))
		return
	end

	sendMergeInventory(player)
	Logger.fireClient(mergeResultRemote, player, true, "MERGE_COMPLETE")
end

ProfileDb.OnProfileLoaded(sendCurrencyUpdated)
ProfileApi.Db.OnProfileLoaded(sendMergeInventory)
Logger.onServerEvent(requestMergeInventoryRemote, "LobbyServerRuntime", onMergeInventoryRequested)
Logger.onServerEvent(mergeGunsRemote, "LobbyServerRuntime", onMergeGunsRequested)
ProfileDb.OnProfileChanged(sendCurrencyUpdated)

-- ── Lobby services ───────────────────────────────────────────────────────────

local services = server_script_service.lobby.services

require(services.MatchQueueService)        -- no deps
require(services.TeleportHelperService)    -- no deps
require(services.MatchmakingService)       -- requires MatchQueueService, TeleportHelperService
require(services.LightShowService)         -- no deps
require(services.FlyoverService)           -- no deps
require(replicated_storage.common.purchase.purchase_framework)
Logger.info("LobbyServerRuntime", "Booting — 5 services registered.")
Framework.Start()
Logger.info("LobbyServerRuntime", "Framework started. All services live.")
