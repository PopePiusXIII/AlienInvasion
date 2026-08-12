--!strict
--------------------------------------------------------------------------------
-- Profile-bound economy operations: run rewards, weapon unlocks, and purchases.
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Logger = require(replicated_storage.common.shared.logger)
local CombatConfig: any = require(replicated_storage.common.shared.configs.combat_config)
local GunCore = require(replicated_storage.common.shared.gun_core)
local ProfileDbType = require(replicated_storage.common.shared.profile_db_types)
local ProfileDb = require(server_script_service.common.services.profile_db)

local TAG = "EconomyApi"
local ONE_HUNDRED_GOLD_DEVELOPER_ID = 3608323068

type EconomySummary = ProfileDbType.EconomySummary
type WeaponUnlocks = ProfileDbType.WeaponUnlocks

local EconomyApi = {}

local function isRarityUnlocked(unlockedWeapons: WeaponUnlocks, weaponName: string, rarity: GunCore.GunRarity): boolean
	local unlockedRarities = unlockedWeapons[weaponName]
	if not unlockedRarities then
		return false
	end

	return unlockedRarities[rarity] == true
end

local function getOrCreateUnlockedRarities(unlockedWeapons: WeaponUnlocks, weaponName: string): { [GunCore.GunRarity]: boolean }
	local unlockedRarities = unlockedWeapons[weaponName]
	if not unlockedRarities then
		unlockedRarities = {}
		unlockedWeapons[weaponName] = unlockedRarities
	end
	return unlockedRarities
end

function EconomyApi.saveStats(player: Player, waveReached: number, economy: EconomySummary?)
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot save stats for %s — profile not loaded.", player.Name)
		return
	end

	local silverEarned = economy and economy.silverEarned or 0
	local silverSpent = economy and economy.silverSpent or 0
	local goldEarned = economy and economy.goldEarned or 0

	profile.bestWave = math.max(profile.bestWave, waveReached)
	profile.totalGames += 1
	profile.lifetimeSilverEarned += silverEarned
	profile.lifetimeSilverSpent += silverSpent
	profile.goldStuds += goldEarned

	Logger.info(TAG, "Saved stats for %s — wave %d.", player.Name, waveReached)
	ProfileDb.NotifyChanged(player, profile)
	ProfileDb.save(player)
end

function EconomyApi.isWeaponUnlocked(player: Player, weaponName: string, rarity: GunCore.GunRarity): boolean
	local profile = ProfileDb:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot check unlock %s for %s — profile not loaded.", weaponName, player.Name)
		return false
	end
	return isRarityUnlocked(profile.unlockedWeapons, weaponName, rarity)
end

function EconomyApi.tryUnlockWeapon(player: Player, weaponName: string, rarity: GunCore.GunRarity): (boolean, string)
	local variants = CombatConfig[weaponName]
	local gun = variants and variants[rarity]
	local goldCost = gun and gun.gold_cost
	if goldCost == nil then
		return false, "UNKNOWN_WEAPON"
	end

	local profile = ProfileDb:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot unlock %s for %s — profile not loaded.", weaponName, player.Name)
		return false, "PROFILE_NOT_LOADED"
	end
	if isRarityUnlocked(profile.unlockedWeapons, weaponName, rarity) then
		return false, "ALREADY_UNLOCKED"
	end
	if profile.goldStuds < goldCost then
		return false, "INSUFFICIENT_GOLD"
	end

	profile.goldStuds -= goldCost
	local unlockedRarities = getOrCreateUnlockedRarities(profile.unlockedWeapons, weaponName)
	unlockedRarities[rarity] = true
	Logger.info(TAG, "%s unlocked %s at %s rarity for %d gold.", player.Name, weaponName, rarity, goldCost)
	ProfileDb.NotifyChanged(player, profile)
	return true, "OK"
end

function EconomyApi.buyDeveloperGold(player: Player, devProductId: number): boolean
	local goldRewards = {
		[ONE_HUNDRED_GOLD_DEVELOPER_ID] = 100,
	}
	local goldAmount = goldRewards[devProductId]
	if not goldAmount then
		Logger.warn(TAG, "Unknown dev product ID %d from player %s.", devProductId, player.Name)
		return false
	end

	local profile = ProfileDb:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot grant gold to %s — profile not loaded.", player.Name)
		return false
	end

	profile.goldStuds += goldAmount
	Logger.info(TAG, "%s purchased %d gold via dev product %d.", player.Name, goldAmount, devProductId)
	ProfileDb.save(player)
	ProfileDb.NotifyChanged(player, profile)
	return true
end

local EconomyAPI: ProfileDbType.EconomyAPI = EconomyApi

return EconomyAPI