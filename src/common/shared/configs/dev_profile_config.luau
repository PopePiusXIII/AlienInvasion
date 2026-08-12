--!strict
-- Complete, Studio-only profile presets for deterministic local testing.

local replicated_storage = game:GetService("ReplicatedStorage")

local ProfileDbType = require(replicated_storage.common.shared.profile_db_types)

local profiles: { [string]: ProfileDbType.PlayerProfile } = {
	EMPTY = {
		schemaVersion = 1,
		bestWave = 0,
		totalGames = 0,
		goldStuds = 0,
		lifetimeSilverEarned = 0,
		lifetimeSilverSpent = 0,
		unlockedWeapons = {},
		inventory = {},
	},
	FULL_LOADOUT = {
		schemaVersion = 1,
		bestWave = 25,
		totalGames = 10,
		goldStuds = 10_000,
		lifetimeSilverEarned = 25_000,
		lifetimeSilverSpent = 5_000,
		unlockedWeapons = {
			["1911"] = { common = true },
			MP5 = { common = true },
			SCAR = { common = true },
		},
		inventory = {
			["DEV-COMMON-1911"] = {
				id = "DEV-COMMON-1911",
				name = "1911",
				rarity = "common",
			},
			["DEV-COMMON-MP5"] = {
				id = "DEV-COMMON-MP5",
				name = "MP5",
				rarity = "common",
			},
		},
	},
}

return {
	USE_SPOOF = true,
	ACTIVE_PROFILE = "FULL_LOADOUT",
	PROFILES = profiles,
}