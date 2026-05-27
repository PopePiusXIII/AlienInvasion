-- All tunable game values in one place.
-- Adjust numbers here without touching any logic files.
return {
	-- Zombie
	ZOMBIE_MAX_HEALTH      = 50,
	ZOMBIE_WALK_SPEED      = 14,
	ZOMBIE_TOUCH_DAMAGE    = 10,
	ZOMBIE_DAMAGE_COOLDOWN = 1,    -- seconds between touch hits
	ZOMBIE_CHASE_INTERVAL  = 0.1,  -- how often MoveTo refreshes
	ZOMBIE_SPAWN_DISTANCE  = 100,  -- exact studs from map centre
	ZOMBIE_SPAWN_HEIGHT    = 3,    -- studs above ground

	-- Gun (Deagle)
	GUN_NAME          = "Deagle",
	GUN_DAMAGE        = 34,
	GUN_RANGE         = 1000,
	GUN_FIRE_COOLDOWN = 0.15,
	GUN_MAG_SIZE      = 7,      -- Desert Eagle holds 7 rounds
	GUN_RELOAD_TIME   = 2.0,    -- seconds to reload
	GUN_MUZZLE_DELAY  = 0.05,   -- how long the flash stays visible

	-- Wave progression
	STARTING_WAVE       = 2,
	WAVE_START_DELAY    = 3,
	WAVE_BETWEEN_DELAY  = 5,
	WAVE_SPAWN_INTERVAL = 1,

	-- Player movement
	PLAYER_WALK_SPEED   = 16,
	PLAYER_SPRINT_SPEED = 30,
	PLAYER_JUMP_POWER   = 70,

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
}
