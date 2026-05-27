-- Config.luau  (Lobby Place)
-- Matchmaking constants used by lobby server and client scripts.
-- Keep LOBBY_PLACE_ID / MATCH_PLACE_ID in sync with the Match Place Config.
return {
	-- TODO: Replace 0s with your actual Roblox Place IDs after publishing both places.
	LOBBY_PLACE_ID    = 0,
	MATCH_PLACE_ID    = 0,

	MATCH_SIZE        = 4,           -- players grouped into each reserved server
	QUEUE_POLL_RATE   = 3,           -- seconds between matchmaker queue checks
	MEMORY_STORE_NAME = "MatchQueue",

	-- Observability — flip to true to trace every RemoteEvent payload.
	DEBUG_NETWORKING  = false,
	DEBUG_VERBOSE     = false,
}
