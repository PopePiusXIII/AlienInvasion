--!strict
-- Profile-bound gun inventory, rarity upgrade, and stat resolution operations.
--------------------------------------------------------------------------------

local HttpService = game:GetService("HttpService")
local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Logger = require(replicated_storage.common.shared.logger)
local CombatConfig: any = require(replicated_storage.common.shared.configs.combat_config)
local GunCore = require(replicated_storage.common.shared.gun_core)
local ProfileDbType = require(replicated_storage.common.shared.profile_db_types)
local GunMerge = require(server_script_service.common.services.gun_merge)
local ProfileDb = require(server_script_service.common.services.profile_db)

local TAG = "GunApi"

type GunInstance = GunCore.GunInstance
type StoredGun = ProfileDbType.StoredGun

local GunApi = {}

local function generateGunId(): string
	return HttpService:GenerateGUID():upper()
end

local function createGunInstance(id: string, storedGun: StoredGun): GunInstance
	return {
		id = id,
		name = storedGun.name,
		rarity = storedGun.rarity,
	}
end

function GunApi.grantGun(player: Player, gunName: string, rarity: GunCore.GunRarity): string?
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot grant %s to %s — profile not loaded.", gunName, player.Name)
		return nil
	end

	local gunVariants = CombatConfig[gunName]
	local gun = gunVariants and gunVariants[rarity]
	if not gun then
		Logger.warn(TAG, "Cannot grant %s at %s rarity — no variant in CombatConfig.", gunName, rarity)
		return nil
	end

	local unlockedRarities = profile.unlockedWeapons[gunName]
	if not unlockedRarities then
		unlockedRarities = {}
		profile.unlockedWeapons[gunName] = unlockedRarities
	end
	unlockedRarities[rarity] = true
	local id = generateGunId()
	profile.inventory[id] = { name = gunName, rarity = rarity }

	Logger.info(TAG, "%s granted %s at %s rarity (id=%s).", player.Name, gunName, rarity, id)
	ProfileDb.save(player)
	return id
end

function GunApi.getInventory(player: Player): { GunInstance }?
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		return nil
	end

	local result: { GunInstance } = {}
	for id, storedGun in profile.inventory do
		table.insert(result, createGunInstance(id, storedGun))
	end
	return result
end

function GunApi.getGun(player: Player, gunId: string): GunInstance?
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		return nil
	end
	local storedGun = profile.inventory[gunId]
	if not storedGun then
		return nil
	end
	return createGunInstance(gunId, storedGun)
end

function GunApi.removeGun(player: Player, gunId: string): boolean
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot remove %s from %s — profile not loaded.", gunId, player.Name)
		return false
	end

	local instance = profile.inventory[gunId]
	if not instance then
		Logger.warn(TAG, "Gun %s not found in %s's inventory.", gunId, player.Name)
		return false
	end

	profile.inventory[gunId] = nil
	Logger.info(TAG, "%s removed %s (%s).", player.Name, instance.name, gunId)
	ProfileDb.save(player)
	return true
end

function GunApi.mergeGuns(player: Player, gunIds: { string }): (boolean, string?, string?)
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		return false, nil, "PROFILE_NOT_LOADED"
	end
	if #gunIds < 2 then
		return false, nil, "NOT_ENOUGH_GUNS"
	end

	local instances: { GunInstance } = {}
	for _, gunId in ipairs(gunIds) do
		local storedGun = profile.inventory[gunId]
		if not storedGun then
			return false, nil, "GUN_NOT_FOUND"
		end
		table.insert(instances, createGunInstance(gunId, storedGun))
	end

	local first = instances[1]
	for _, instance in ipairs(instances) do
		if instance.name ~= first.name or instance.rarity ~= first.rarity then
			return false, nil, "MISMATCHED_GUNS"
		end
	end

	local newRarity: GunCore.GunRarity = GunMerge.merge_guns(instances)
	if newRarity == first.rarity then
		return false, nil, "CANNOT_UPGRADE_FURTHER"
	end

	local targetVariants = CombatConfig[first.name]
	if not targetVariants or not targetVariants[newRarity] then
		Logger.warn(TAG, "Target variant %s at %s rarity not found in CombatConfig.", first.name, newRarity)
		return false, nil, "TARGET_VARIANT_MISSING"
	end

	for _, instance in ipairs(instances) do
		profile.inventory[instance.id] = nil
	end

	local id = generateGunId()
	profile.inventory[id] = { name = first.name, rarity = newRarity }
	Logger.info(TAG, "%s merged %d %s %s into %s (id=%s).", player.Name, #instances, first.rarity, first.name, newRarity, id)
	ProfileDb.save(player)
	return true, id, nil
end

function GunApi.upgradeLevel(player: Player, gunId: string): (boolean, number?, string?)
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		return false, nil, "PROFILE_NOT_LOADED"
	end

	local instance = profile.inventory[gunId]
	if not instance then
		return false, nil, "GUN_NOT_FOUND"
	end

	Logger.info(TAG, "%s upgraded %s via RNG (in-memory).", player.Name, instance.name)
	return true, nil, nil
end

function GunApi.getGunStats(player: Player, gunId: string, level: number?): GunCore.Gun?
	local instance = GunApi.getGun(player, gunId)
	if not instance then
		return nil
	end

	local variants = CombatConfig[instance.name]
	local base = variants and variants[instance.rarity]
	if not base then
		Logger.warn(TAG, "No stats for %s at %s rarity.", instance.name, instance.rarity)
		return nil
	end

	local effectiveLevel = level or 1
	local modifier = CombatConfig.LEVEL_MULTIPLIERS[effectiveLevel] :: GunCore.GunLevelModifier
	if not modifier then
		error(string.format("No level modifier configured for level %d.", effectiveLevel))
	end

	return {
		rarity = instance.rarity,
		damage = math.floor(base.damage * modifier.damage),
		gold_cost = base.gold_cost,
		image = base.image,
		range = math.floor(base.range * modifier.range),
		fireCooldown = base.fireCooldown / modifier.cooldownDiv,
		magSize = math.max(1, math.floor(base.magSize * modifier.magSize)),
		max_ammo = base.max_ammo,
		reloadTime = base.reloadTime,
		isAutomatic = base.isAutomatic,
		isShotgun = base.isShotgun,
		knockbackForce = math.floor(base.knockbackForce * modifier.knockback),
		tracer = base.tracer,
	}
end

local GunAPI: ProfileDbType.GunAPI = GunApi

return GunAPI
