-- Config.luau  (Lobby Place)
-- Matchmaking constants used by lobby server and client scripts.
-- Keep LOBBY_PLACE_ID / MATCH_PLACE_ID in sync with the Match Place Config.
return {
	-- TODO: Replace 0s with your actual Roblox Place IDs after publishing both places.
	LOBBY_PLACE_ID    = 0,
	MATCH_PLACE_ID    = 139480589390980,

	LOBBY_PAD_NAME    = "GoToGame",  -- workspace part that gates the Find Match UI

	MATCH_SIZE        = 1,           -- players grouped into each reserved server
	QUEUE_POLL_RATE   = 3,           -- seconds between matchmaker queue checks
	MEMORY_STORE_NAME = "MatchQueue",

	-- Observability — flip to true to trace every RemoteEvent payload.
	DEBUG_NETWORKING  = false,
	DEBUG_VERBOSE     = false,

	-- Test mode — if true, disables teleporter and keeps players in lobby
	TEST_MODE = true,

	-- Player character stats (synced with Match place)
	PLAYER_WALK_SPEED   = 16,
	PLAYER_SPRINT_SPEED = 30,
	PLAYER_JUMP_POWER   = 70,
	PLAYER_MELEE_POWER  = 10,
	PLAYER_SCALE        = 1,

	-- Flyover configuration
	FLYOVER_VELOCITY   = 200,
	FLYOVER_LOOP_DELAY = 20,
}
