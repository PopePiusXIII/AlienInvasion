--!strict

local GunCatalogModule = {}

export type GunTracerStyle = {
	lifetime: number,
	thickness: number,
	color: Color3,
}

export type GunStats = {
	damage: number,
	range: number,
	fireCooldown: number,
	magSize: number,
	reloadTime: number,
	isAutomatic: boolean,
	knockbackForce: number,
	tracer: GunTracerStyle,
}

function GunCatalogModule.getGunStats(config: { [string]: any }, gunName: string?): GunStats
	local defaultTracer = config.GUN_TRACER_DEFAULT :: GunTracerStyle
	local statsByName = config.GUN_STATS :: { [string]: { [string]: any } }
	if gunName and statsByName[gunName] then
		local gunStats = statsByName[gunName]
		return {
			damage = gunStats.damage,
			range = gunStats.range,
			fireCooldown = gunStats.fireCooldown,
			magSize = gunStats.magSize,
			reloadTime = gunStats.reloadTime,
			isAutomatic = gunStats.isAutomatic == true,
			knockbackForce = gunStats.knockbackForce or config.GUN_KNOCKBACK_FORCE,
			tracer = (gunStats.tracer :: GunTracerStyle?) or defaultTracer,
		}
	end
	return {
		damage = config.GUN_DAMAGE,
		range = config.GUN_RANGE,
		fireCooldown = config.GUN_FIRE_COOLDOWN,
		magSize = config.GUN_MAG_SIZE,
		reloadTime = config.GUN_RELOAD_TIME,
		isAutomatic = false,
		knockbackForce = config.GUN_KNOCKBACK_FORCE,
		tracer = defaultTracer,
	}
end

function GunCatalogModule.isSupportedGunName(config: { [string]: any }, name: string): boolean
	local statsByName = config.GUN_STATS :: { [string]: { [string]: any } }
	return statsByName[name] ~= nil
end

return GunCatalogModule
