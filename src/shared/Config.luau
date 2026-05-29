--!strict
-- All tunable game values in one place.
-- Adjust numbers here without touching any logic files.
return {
	-- Zombie
	ZOMBIE_MAX_HEALTH      = 50,
	ZOMBIE_WALK_SPEED      = 14,
	ZOMBIE_TOUCH_DAMAGE    = 10,
	ZOMBIE_DAMAGE_COOLDOWN = 1,    -- seconds between touch hits
	ZOMBIE_CHASE_INTERVAL  = 0.1,  -- how often MoveTo refreshes
	ZOMBIE_SPAWN_DISTANCE  = 100,  -- unused; zombies now spawn at the Spawn_Mob part in the map
	ZOMBIE_SPAWN_HEIGHT    = 3,    -- studs above ground

	-- Gun
	-- Active wave gun granted by WaveService; set to M82 as the strong default.
	GUN_NAME = "M82",
	-- Backward-compatible baseline values (used as fallback profile).
	GUN_DAMAGE        = 34,
	GUN_RANGE         = 1000,
	GUN_FIRE_COOLDOWN = 0.15,
	GUN_MAG_SIZE      = 7,
	GUN_RELOAD_TIME   = 2.0,
	GUN_MUZZLE_DELAY  = 0.05,
	GUN_TRACER_DEFAULT = {
		lifetime = 0.06,
		thickness = 0.08,
		color = Color3.fromRGB(255, 235, 170),
	},
	STARTER_UNLOCKED_WEAPONS = {
		"Deagle",
		"M82",
	},
	GOLD_WEAPON_UNLOCK_PRICES = {
		Deagle = 0,
		M82 = 0,
		M60 = 120,
		M240B = 180,
	},
	BOLT_RISE_DURATION        = 0.5,
	BOLT_HOVER_HEIGHT         = 0.5,
	BOLT_ATTRACT_RADIUS       = 20,
	BOLT_ATTRACT_ACCELERATION = 15,
	SILVER_START_BALANCE = 0,
	SILVER_DROP_BY_ZOMBIE_TYPE = {
		Normal = { min = 2, max = 5 },
		Fast = { min = 3, max = 6 },
		Tank = { min = 5, max = 10 },
	},
	SILVER_WAVE_MULTIPLIER_STEP = 0.06,
	GOLD_DROP_BY_ZOMBIE_TYPE = {
		Normal = { chance = 0.035, min = 1, max = 3 },
		Fast = { chance = 0.06, min = 1, max = 4 },
		Tank = { chance = 0.1, min = 2, max = 6 },
	},
	GOLD_WAVE_CHANCE_STEP = 0.015,
	GOLD_WAVE_REWARD_STEP = 0.04,
	ZOMBIE_DEFAULT_TYPE = "Normal",
	SHOP_SILVER_PRICES = {
		ammoRefill = 30,
		healthPack = 55,
		damageBoost = 75,
		speedBoost = 60,
	},
	-- Per-weapon runtime stats used by GunController and CombatService.
	GUN_STATS = {
		Deagle = {
			damage = 34,
			range = 1000,
			fireCooldown = 0.15,
			magSize = 7,
			reloadTime = 2.0,
			isAutomatic = false,
			tracer = {
				lifetime = 0.045,
				thickness = 0.05,
				color = Color3.fromRGB(255, 241, 160),
			},
		},
		M82 = {
			damage = 250,
			range = 2500,
			fireCooldown = 0.1,
			magSize = 100,
			reloadTime = 2.8,
			isAutomatic = true,
			tracer = {
				lifetime = 0.08,
				thickness = 0.11,
				color = Color3.fromRGB(255, 219, 130),
			},
		},
		M60 = {
			damage = 42,
			range = 1800,
			fireCooldown = 0.08,
			magSize = 100,
			reloadTime = 4.2,
			isAutomatic = true,
			tracer = {
				lifetime = 0.055,
				thickness = 0.075,
				color = Color3.fromRGB(255, 226, 140),
			},
		},
		M240B = {
			damage = 46,
			range = 2000,
			fireCooldown = 0.09,
			magSize = 100,
			reloadTime = 4.4,
			isAutomatic = true,
			tracer = {
				lifetime = 0.06,
				thickness = 0.08,
				color = Color3.fromRGB(255, 214, 128),
			},
		},
	},

	-- Wave progression
	STARTING_WAVE            = 20,
	WAVE_START_DELAY         = 3,
	WAVE_BETWEEN_DELAY       = 5,
	WAVE_SPAWN_INTERVAL      = 1,
	WAVE_CLEAR_SPEED_BOOST   = 10,   -- added to walk/sprint speed per cleared wave
	WAVE_CLEAR_SCALE_BOOST   = 0.5, -- added to character scale per cleared wave

	-- Player movement
	PLAYER_WALK_SPEED   = 16,
	PLAYER_SPRINT_SPEED = 30,
	PLAYER_JUMP_POWER   = 70,
	PLAYER_MELEE_POWER  = 10,
	PLAYER_SCALE        = 1,

	-- Map and Lobby
	LOBBY_NAME     = "Lobby_Football",
	MAP_NAME       = "Map_FastFood",
	LOBBY_PAD_NAME = "GoToGame",

	-- Multi-Place Matchmaking
	-- TODO: Fill in your actual Roblox Place IDs after publishing both places.
	LOBBY_PLACE_ID     = 0,
	MATCH_PLACE_ID     = 0,
	MATCH_SIZE         = 4,          -- players per reserved match server
	QUEUE_POLL_RATE    = 3,          -- seconds between matchmaker queue checks
	MATCH_WAIT_TIMEOUT = 15,         -- seconds to wait for players before auto-starting
	MEMORY_STORE_NAME  = "MatchQueue",
	DATA_STORE_NAME    = "PlayerStats",

	-- ── Observability ──────────────────────────────────────────────────────────
	-- Flip DEBUG_NETWORKING to true to trace every RemoteEvent payload through
	-- the Logger middleware (direction, remote name, serialized args).
	-- Can also be hot-toggled at runtime in the Studio console:
	--   require(game.ReplicatedStorage.Shared.Logger).DEBUG_NETWORKING = true
	DEBUG_NETWORKING = true,
	-- Flip DEBUG_VERBOSE to true for high-frequency logs (AI loops, per-frame data).
	DEBUG_VERBOSE    = true,
}
