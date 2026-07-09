--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunModule = require(ReplicatedStorage.Shared.Gun)

local GunCatalogModule = {}

function GunCatalogModule.getGunStats(config: { [string]: any }, gunName: string?): GunModule.Gun
	local defaultTracer = config.GUN_TRACER_DEFAULT :: GunModule.GunTracer
	local gun = config.GUN_STATS[gunName] :: GunModule.Gun?
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

function GunCatalogModule.isSupportedGunName(config: { [string]: any }, name: string): boolean
	return config.GUN_STATS[name] ~= nil
end

return GunCatalogModule
