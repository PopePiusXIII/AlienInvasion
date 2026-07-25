--!strict
--------------------------------------------------------------------------------
-- gun_api.luau  (src/common → server_script_service.gun_api)
-- Profile-bound gun operations: resolve stats, manage inventory, merge/upgrade.
-- All methods require a Player reference — they hit the profile store.
-- SERVER ONLY. Do not require from client code.
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local ProfileService = require(server_script_service.common.services.profile_db)
local GunCore = require(replicated_storage.common.shared.gun_core)

local GunApi = {}

--- Resolve full stats for a gun instance (base rarity + level multipliers).
--- `level` is the in-memory match level (1-4). Defaults to 1 if not provided.
function GunApi.getStats(player: Player, gunId: string, level: number?): GunCore.Gun?
	return ProfileService.getGunStats(player, gunId, level)
end

--- Get a single gun instance by ID (rarity, name — no level).
function GunApi.get(player: Player, gunId: string): GunCore.GunInstance?
	return ProfileService.getGun(player, gunId)
end

--- Get all gun instances from the player's profile.
function GunApi.getInventory(player: Player): { GunCore.GunInstance }?
	return ProfileService.getInventory(player)
end

--- Grant a gun at common rarity, level 1. Returns new gun ID or nil on error.
function GunApi.grant(player: Player, gunName: string): string?
	return ProfileService.grantGun(player, gunName)
end

--- Remove a gun by ID.
function GunApi.remove(player: Player, gunId: string): boolean
	return ProfileService.removeGun(player, gunId)
end

--- Merge same-rarity guns into next tier (consumes sources).
--- Returns (success, newGunId?, errorMessage?).
function GunApi.merge(player: Player, gunIds: { string }): (boolean, string?, string?)
	return ProfileService.mergeGuns(player, gunIds)
end

return GunApi
