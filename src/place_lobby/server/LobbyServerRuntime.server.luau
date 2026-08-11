--!strict
--------------------------------------------------------------------------------
-- LobbyServerRuntime.server.luau  (places/lobby/src/server)
-- THE single server entry point for the Lobby Place.
-- Requires all Lobby services and starts the framework.
-- NO game logic here — belongs in the appropriate service.
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.shared.framework)
local Logger    = require(replicated_storage.shared.logger)

-- ── Shared services (cross-place) ────────────────────────────────────────────
require(server_script_service.ProfileService)

-- ── Lobby services ───────────────────────────────────────────────────────────

local services = script.Parent.services

require(services.MatchQueueService)        -- no deps
require(services.TeleportHelperService)    -- no deps
require(services.MatchmakingService)       -- requires MatchQueueService, TeleportHelperService
require(services.LightShowService)         -- no deps
require(services.FlyoverService)           -- no deps
require(services.PlayerInitService)        -- requires ProfileService
require(replicated_storage.shared.purchase.purchaseFramework)
Logger.info("LobbyServerRuntime", "Booting — 6 services registered.")
Framework.Start()
Logger.info("LobbyServerRuntime", "Framework started. All services live.")
