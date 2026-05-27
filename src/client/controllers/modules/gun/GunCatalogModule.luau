--!strict

local GunCatalogModule = {}

export type GunStats = {
	damage: number,
	range: number,
	fireCooldown: number,
	magSize: number,
	reloadTime: number,
}

function GunCatalogModule.getGunStats(config: { [string]: any }, gunName: string?): GunStats
	local statsByName = config.GUN_STATS :: { [string]: GunStats }
	if gunName and statsByName[gunName] then
		return statsByName[gunName]
	end
	return {
		damage = config.GUN_DAMAGE,
		range = config.GUN_RANGE,
		fireCooldown = config.GUN_FIRE_COOLDOWN,
		magSize = config.GUN_MAG_SIZE,
		reloadTime = config.GUN_RELOAD_TIME,
	}
end

function GunCatalogModule.isSupportedGunName(config: { [string]: any }, name: string): boolean
	local statsByName = config.GUN_STATS :: { [string]: GunStats }
	return statsByName[name] ~= nil
end

return GunCatalogModule
