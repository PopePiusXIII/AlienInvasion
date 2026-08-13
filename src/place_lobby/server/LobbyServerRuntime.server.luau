--!strict
--------------------------------------------------------------------------------
-- LobbyServerRuntime.server.luau  (places/lobby/src/server)
-- THE single server entry point for the Lobby Place.
-- Requires all Lobby services and starts the framework.
-- NO game logic here — belongs in the appropriate service.
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.common.shared.framework)
local Logger    = require(replicated_storage.common.shared.logger)

-- ── Shared services (cross-place) ────────────────────────────────────────────
require(server_script_service.common.services.profile_db)

-- ── Lobby services ───────────────────────────────────────────────────────────

local services = server_script_service.lobby.services

require(services.MatchQueueService)        -- no deps
require(services.TeleportHelperService)    -- no deps
require(services.MatchmakingService)       -- requires MatchQueueService, TeleportHelperService
require(services.LightShowService)         -- no deps
require(services.FlyoverService)           -- no deps
require(replicated_storage.common.purchase.purchase_framework)
Logger.info("LobbyServerRuntime", "Booting — 5 services registered.")
Framework.Start()
Logger.info("LobbyServerRuntime", "Framework started. All services live.")
