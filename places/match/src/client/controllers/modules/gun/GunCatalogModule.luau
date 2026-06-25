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
	isShotgun: boolean,
	knockbackForce: number,
	max_ammo: number,
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
			isShotgun = gunStats.isShotgun == true,
			knockbackForce = gunStats.knockbackForce or config.GUN_KNOCKBACK_FORCE,
			max_ammo = gunStats.max_ammo or config.DEFAULT_GUN_RESERVE or 0,
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
		isShotgun = false,
		knockbackForce = config.GUN_KNOCKBACK_FORCE,
		max_ammo = config.DEFAULT_GUN_RESERVE or 0,
		tracer = defaultTracer,
	}
end

function GunCatalogModule.isSupportedGunName(config: { [string]: any }, name: string): boolean
	local statsByName = config.GUN_STATS :: { [string]: { [string]: any } }
	return statsByName[name] ~= nil
end

return GunCatalogModule
