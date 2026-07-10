--!strict
--------------------------------------------------------------------------------
-- GunApi.luau  (src/shared → ReplicatedStorage.Shared.GunApi)
-- Profile-bound gun operations: resolve stats, manage inventory, merge/upgrade.
-- All methods require a Player reference — they hit the profile store.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileService = require(ReplicatedStorage.Shared.ProfileService)
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local GunCore = require(ReplicatedStorage.Shared.GunCore)

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

--- Check if a base weapon name exists in GUN_STATS.
function GunApi.isSupportedGunName(name: string): boolean
	return CombatConfig.GUN_STATS[CombatConfig.getGunStatsKey(name, "common")] ~= nil
end

--- Client-side stats resolution (no profile needed — uses synced gun data).
--- Call this from the client with rarity/level received via inventory sync.
function GunApi.resolveStats(gunName: string, rarity: string, level: number): GunCore.Gun?
	local statsKey = CombatConfig.getGunStatsKey(gunName, rarity)
	local base = CombatConfig.GUN_STATS[statsKey]
	if not base then return nil end

	local mod: GunCore.GunLevelModifier = CombatConfig.LEVEL_MULTIPLIERS[level] :: GunCore.GunLevelModifier
	     or CombatConfig.LEVEL_MULTIPLIERS[1] :: GunCore.GunLevelModifier

	return {
		rarity         = rarity,
		damage         = math.floor(base.damage * mod.damage),
		gold_cost      = base.gold_cost,
		image          = base.image,
		range          = math.floor(base.range * mod.range),
		fireCooldown   = base.fireCooldown / mod.cooldownDiv,
		magSize        = math.max(1, math.floor(base.magSize * mod.magSize)),
		max_ammo       = base.max_ammo or 0,
		reloadTime     = base.reloadTime,
		isAutomatic    = base.isAutomatic == true,
		isShotgun      = base.isShotgun == true,
		knockbackForce = math.floor(base.knockbackForce * mod.knockback),
		tracer         = base.tracer,
	}
end

return GunApi
