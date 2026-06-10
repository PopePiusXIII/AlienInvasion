--!strict
--------------------------------------------------------------------------------
-- DataService.luau  (src/server/services)
-- Handles all DataStore I/O. No game logic lives here.
-- Single Responsibility: persistent player data read/write.
--
-- Public API:
--   DataService.saveStats(player, waveReached)
--     Atomically updates bestWave and totalGames via UpdateAsync.
--------------------------------------------------------------------------------

local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)

local TAG = "DataService"

local DataService = Framework.CreateService({ Name = TAG })

local _statsStore: DataStore
local _profileCache: { [Player]: { [string]: any } } = {}

type PlayerProfile = {
	bestWave: number,
	totalGames: number,
	goldStuds: number,
	lifetimeSilverEarned: number,
	lifetimeSilverSpent: number,
	unlockedWeapons: { [string]: boolean },
}

type EconomySummary = {
	silverEarned: number,
	silverSpent: number,
	goldEarned: number,
}

local function defaultUnlockedWeapons(): { [string]: boolean }
	local unlocked: { [string]: boolean } = {}
	for _, weaponName in ipairs(Config.STARTER_UNLOCKED_WEAPONS :: { string }) do
		unlocked[weaponName] = true
	end
	return unlocked
end

local function createDefaultProfile(): PlayerProfile
	return {
		bestWave = 0,
		totalGames = 0,
		goldStuds = 0,
		lifetimeSilverEarned = 0,
		lifetimeSilverSpent = 0,
		unlockedWeapons = defaultUnlockedWeapons(),
	}
end

local function normalizeProfile(existing: any?): PlayerProfile
	local base = createDefaultProfile()
	if type(existing) ~= "table" then
		return base
	end

	local profile = existing :: { [string]: any }
	base.bestWave = tonumber(profile.bestWave) or base.bestWave
	base.totalGames = tonumber(profile.totalGames) or base.totalGames
	base.goldStuds = tonumber(profile.goldStuds) or base.goldStuds
	base.lifetimeSilverEarned = tonumber(profile.lifetimeSilverEarned) or base.lifetimeSilverEarned
	base.lifetimeSilverSpent = tonumber(profile.lifetimeSilverSpent) or base.lifetimeSilverSpent

	if type(profile.unlockedWeapons) == "table" then
		for weaponName, isUnlocked in pairs(profile.unlockedWeapons :: { [string]: any }) do
			if isUnlocked == true then
				base.unlockedWeapons[tostring(weaponName)] = true
			end
		end
	end

	return base
end

local function getPlayerKey(player: Player): string
	return "player_" .. tostring(player.UserId)
end

local function cacheProfile(player: Player, profile: PlayerProfile): PlayerProfile
	_profileCache[player] = profile
	return profile
end

local function loadProfile(player: Player): PlayerProfile
	local cached = _profileCache[player]
	if cached then
		return cached :: PlayerProfile
	end

	local key = getPlayerKey(player)
	local loaded: any = nil
	local ok, err = pcall(function()
		loaded = _statsStore:GetAsync(key)
	end)
	if not ok then
		Logger.warn(TAG, "Load failed for %s: %s", player.Name, tostring(err))
		return cacheProfile(player, createDefaultProfile())
	end

	return cacheProfile(player, normalizeProfile(loaded))
end

function DataService:Init()
	_statsStore = DataStoreService:GetDataStore(Config.DATA_STORE_NAME)
	Logger.info(TAG, "DataStore '%s' initialized.", Config.DATA_STORE_NAME)
end

function DataService:Start()
	game:GetService("Players").PlayerAdded:Connect(function(player: Player)
		loadProfile(player)
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		_profileCache[player] = nil
	end)

	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		loadProfile(player)
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Persist the wave reached for a player.
--- Uses UpdateAsync for atomic read-modify-write — safe for concurrent callers.
function DataService.saveStats(player: Player, waveReached: number, economy: EconomySummary?)
	local key = getPlayerKey(player)
	local silverEarned = economy and economy.silverEarned or 0
	local silverSpent = economy and economy.silverSpent or 0
	local goldEarned = economy and economy.goldEarned or 0
	local ok, err = pcall(function()
		_statsStore:UpdateAsync(key, function(existing: any?)
			local data = normalizeProfile(existing)
			data.bestWave   = math.max(data.bestWave, waveReached)
			data.totalGames = data.totalGames + 1
			data.lifetimeSilverEarned += silverEarned
			data.lifetimeSilverSpent += silverSpent
			data.goldStuds += goldEarned
			return data
		end)
	end)
	if not ok then
		Logger.warn(TAG, "Save failed for %s (wave %d): %s", player.Name, waveReached, tostring(err))
	else
		local profile = loadProfile(player)
		profile.bestWave = math.max(profile.bestWave, waveReached)
		profile.totalGames += 1
		profile.lifetimeSilverEarned += silverEarned
		profile.lifetimeSilverSpent += silverSpent
		profile.goldStuds += goldEarned
		Logger.info(TAG, "Saved stats for %s — wave %d.", player.Name, waveReached)
	end
end

function DataService.getProfile(player: Player): PlayerProfile
	return loadProfile(player)
end

function DataService.getGold(player: Player): number
	return loadProfile(player).goldStuds
end

function DataService.isWeaponUnlocked(player: Player, weaponName: string): boolean
	local profile = loadProfile(player)
	return profile.unlockedWeapons[weaponName] == true
end

function DataService.tryUnlockWeapon(player: Player, weaponName: string): (boolean, string)
	local priceTable = Config.GOLD_WEAPON_UNLOCK_PRICES :: { [string]: number }
	local goldCost = priceTable[weaponName]
	if goldCost == nil then
		return false, "UNKNOWN_WEAPON"
	end

	local profile = loadProfile(player)
	if profile.unlockedWeapons[weaponName] == true then
		return false, "ALREADY_UNLOCKED"
	end
	if profile.goldStuds < goldCost then
		return false, "INSUFFICIENT_GOLD"
	end

	local key = getPlayerKey(player)
	local ok, err = pcall(function()
		_statsStore:UpdateAsync(key, function(existing: any?)
			local data = normalizeProfile(existing)
			if data.unlockedWeapons[weaponName] == true then
				return data
			end
			if data.goldStuds < goldCost then
				return data
			end
			data.goldStuds -= goldCost
			data.unlockedWeapons[weaponName] = true
			return data
		end)
	end)
	if not ok then
		Logger.warn(TAG, "Unlock failed for %s (%s): %s", player.Name, weaponName, tostring(err))
		return false, "DATASTORE_ERROR"
	end

	profile.goldStuds -= goldCost
	profile.unlockedWeapons[weaponName] = true
	return true, "OK"
end

return DataService
