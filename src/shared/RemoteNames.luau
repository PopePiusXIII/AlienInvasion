--!strict
--------------------------------------------------------------------------------
-- RemoteNames.luau  (src/shared → ReplicatedStorage.Shared.RemoteNames)
-- Single source of truth for all RemoteEvent name strings (Match Place).
-- Import this in both Services (server) and Controllers (client) to prevent
-- typo-induced nil-remote bugs that only surface at runtime.
--------------------------------------------------------------------------------

return {
	SHOOT_GUN     = "ShootGun",
	WAVE_ANNOUNCE = "WaveAnnounce",
	WAVE_CLEAR    = "WaveClear",
	REQUEST_PLAY  = "RequestPlay",
}
