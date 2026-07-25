--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local GunModule = require(replicated_storage.shared.gun_core)
local CombatConfig = require(replicated_storage.shared.configs.combat_config)
local Logger = require(replicated_storage.shared.logger)

local GunCatalogModule = {}

--- Get base stats for a gun by name (no rarity/level applied).
--- Used for quick lookups where the caller doesn't have instance data.
function GunCatalogModule.getGunStats(config: { [string]: any }, gunName: string?): GunModule.Gun
	local defaultTracer = config.GUN_TRACER_DEFAULT :: GunModule.GunTracer
	-- Try common variant first as fallback for legacy callers
	local gun = CombatConfig.GUN_STATS[CombatConfig.getGunStatsKey(gunName or "", "common")] :: GunModule.Gun?
	if gun then
		return {
			damage = gun.damage,
			range = gun.range,
			fireCooldown = gun.fireCooldown,
			magSize = gun.magSize,
			reloadTime = gun.reloadTime,
			isAutomatic = gun.isAutomatic == true,
			isShotgun = gun.isShotgun == true,
			knockbackForce = gun.knockbackForce or config.GUN_KNOCKBACK_FORCE,
			max_ammo = gun.max_ammo or config.DEFAULT_GUN_RESERVE or 0,
			tracer = (gun.tracer :: GunModule.GunTracer?) or defaultTracer,
		}
	end
	return {
		damage = config.GUN_DAMAGE,
		range = config.GUN_RANGE,
		fireCooldown = config.GUN_FIRE_COOLDOWN,
		magSize = config.GUN_MAG_SIZE,
		reloadTime = config.GUN_RELOAD_TIME,
		isAutomatic = false,
		isShotgun = false,
		knockbackForce = config.GUN_KNOCKBACK_FORCE,
		max_ammo = config.DEFAULT_GUN_RESERVE or 0,
		tracer = defaultTracer,
	}
end

--- Resolve full stats for a gun with rarity + level multipliers applied.
function GunCatalogModule.getResolvedStats(gunName: string, rarity: string, level: number): GunModule.Gun
	local statsKey = CombatConfig.getGunStatsKey(gunName, rarity)
	local base = CombatConfig.GUN_STATS[statsKey]
	if not base then
		Logger.warn("GunCatalog", "No stats for %s.", statsKey)
		return GunCatalogModule.getGunStats({}, gunName)
	end

	local mod: GunModule.GunLevelModifier = CombatConfig.LEVEL_MULTIPLIERS[level] :: GunModule.GunLevelModifier
	     or CombatConfig.LEVEL_MULTIPLIERS[1] :: GunModule.GunLevelModifier

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

function GunCatalogModule.isSupportedGunName(config: { [string]: any }, name: string): boolean
	-- Check if the common variant exists (means the base gun is valid)
	return CombatConfig.GUN_STATS[CombatConfig.getGunStatsKey(name, "common")] ~= nil
end

return GunCatalogModule
