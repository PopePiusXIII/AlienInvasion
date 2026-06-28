--!strict
--------------------------------------------------------------------------------
-- DataService.luau  (src/server/services)
-- Sole owner of all player profile read/write for the Match place.
-- No raw DataStore I/O — ProfileService handles session lifecycle & persistence.
-- All profile mutations flow through this service to avoid double-saves.
--
-- Public API:
--   DataService.saveStats(player, waveReached, economy?)
--     Updates bestWave, totalGames, lifetime silver, and gold from run summary.
--   DataService.getProfile(player)
--     Returns the current player profile (blocks until loaded).
--   DataService.getGold(player)
--     Returns the player's persistent gold balance.
--   DataService.isWeaponUnlocked(player, weaponName)
--     Checks if a weapon is unlocked.
--   DataService.tryUnlockWeapon(player, weaponName)
--     Attempts to unlock a weapon using gold.
--   DataService.saveGoldEarned(player, amount)
--     Adds gold earned during a run to the persistent profile.
--     Called by EconomyService on disconnect to flush unsaved gold.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework      = require(ReplicatedStorage.Shared.Framework)
local Logger         = require(ReplicatedStorage.Shared.Logger)
local ProfileService = require(ReplicatedStorage.Shared.ProfileService)
local Config         = require(ReplicatedStorage.Shared.Config)

local TAG = "DataService"

local DataService = Framework.CreateService({ Name = TAG })

-- Re-export the PlayerProfile type from ProfileService to avoid duplication.
export type PlayerProfile = ProfileService.PlayerProfile

type EconomySummary = {
	silverEarned: number,
	silverSpent: number,
	goldEarned: number,
}

local function grantStarterWeapons(profile: PlayerProfile)
	for _, weaponName in ipairs(Config.STARTER_UNLOCKED_WEAPONS :: { string }) do
		profile.unlockedWeapons[weaponName] = true
	end
end

function DataService:Init()
	Logger.info(TAG, "DataService initialized (ProfileStore backend).")
end

function DataService:Start()
	-- Grant starter weapons on first load via ProfileService profiles
	local Players = game:GetService("Players")

	local function ensureStarterWeapons(player: Player)
		local profile = ProfileService.WaitForProfile(player)
		if profile then
			grantStarterWeapons(profile)
		end
	end

	for _, player in Players:GetPlayers() do
		task.spawn(ensureStarterWeapons, player)
	end

	Players.PlayerAdded:Connect(ensureStarterWeapons)
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Update a player's stats. ProfileStore auto-saves periodically.
function DataService.saveStats(player: Player, waveReached: number, economy: EconomySummary?)
	local profile = ProfileService:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot save stats for %s — profile not loaded.", player.Name)
		return
	end

	local silverEarned = economy and economy.silverEarned or 0
	local silverSpent  = economy and economy.silverSpent or 0
	local goldEarned   = economy and economy.goldEarned or 0

	profile.bestWave             = math.max(profile.bestWave, waveReached)
	profile.totalGames           = profile.totalGames + 1
	profile.lifetimeSilverEarned += silverEarned
	profile.lifetimeSilverSpent  += silverSpent
	profile.goldStuds            += goldEarned

	Logger.info(TAG, "Saved stats for %s — wave %d.", player.Name, waveReached)
end

--- Flush gold earned during a run to the persistent profile.
--- Called by EconomyService on PlayerRemoving to save unsaved gold.
function DataService.saveGoldEarned(player: Player, amount: number)
	local profile = ProfileService:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot flush gold for %s — profile not loaded.", player.Name)
		return
	end

	profile.goldStuds += amount
	Logger.info(TAG, "Flushed %d gold to profile for %s.", amount, player.Name)
end

function DataService.getProfile(player: Player): PlayerProfile
	return ProfileService.WaitForProfile(player) :: PlayerProfile
end

function DataService.getGold(player: Player): number
	return ProfileService.WaitForProfile(player).goldStuds
end

function DataService.isWeaponUnlocked(player: Player, weaponName: string): boolean
	local profile = ProfileService:GetProfile(player)
	if not profile then
		return false
	end
	return profile.unlockedWeapons[weaponName] == true
end

function DataService.tryUnlockWeapon(player: Player, weaponName: string): (boolean, string)
	local priceTable = Config.GOLD_WEAPON_UNLOCK_PRICES :: { [string]: number }
	local goldCost   = priceTable[weaponName]
	if goldCost == nil then
		return false, "UNKNOWN_WEAPON"
	end

	local profile = ProfileService:GetProfile(player)
	if not profile then
		Logger.warn(TAG, "Cannot unlock %s for %s — profile not loaded.", weaponName, player.Name)
		return false, "PROFILE_NOT_LOADED"
	end

	if profile.unlockedWeapons[weaponName] == true then
		return false, "ALREADY_UNLOCKED"
	end

	if profile.goldStuds < goldCost then
		return false, "INSUFFICIENT_GOLD"
	end

	profile.goldStuds -= goldCost
	profile.unlockedWeapons[weaponName] = true

	Logger.info(TAG, "%s unlocked %s for %d gold.", player.Name, weaponName, goldCost)
	return true, "OK"
end

return DataService
