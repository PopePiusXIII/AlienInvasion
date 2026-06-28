--!strict
--------------------------------------------------------------------------------
-- LobbyServerRuntime.server.luau  (places/lobby/src/server)
-- THE single server entry point for the Lobby Place.
-- Requires all Lobby services and starts the framework.
-- NO game logic here — belongs in the appropriate service.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)

-- ── Shared services (cross-place) ────────────────────────────────────────────
require(ReplicatedStorage.Shared.ProfileService)

-- ── Lobby services ───────────────────────────────────────────────────────────

local services = script.Parent.services

require(services.MatchQueueService)        -- no deps
require(services.TeleportHelperService)    -- no deps
require(services.MatchmakingService)       -- requires MatchQueueService, TeleportHelperService
require(services.LightShowService)         -- no deps
require(services.FlyoverService)           -- no deps
require(services.PlayerInitService)        -- requires ProfileService

Logger.info("LobbyServerRuntime", "Booting — 6 services registered.")
Framework.Start()
Logger.info("LobbyServerRuntime", "Framework started. All services live.")
