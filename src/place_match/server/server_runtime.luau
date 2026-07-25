--!strict
--------------------------------------------------------------------------------
-- ServerRuntime.server.luau  (src/server)
-- THE single server entry point for the Match Place.
--
-- Rule: NO game logic lives here. This file only requires services and starts
-- the framework. All logic belongs in the appropriate Service module.
--
-- Require order matters for dependency clarity (not for correctness, since
-- Luau module caching prevents re-execution, but it documents the dep graph):
--   PhysicsSetupService  — no deps
--   ZombieService        — no deps
--   EconomyService       — requires Config/RemoteNames
--   WaveService          — requires ZombieService, EconomyService
--   CombatService        — requires ZombieService, EconomyService
--   PlayerService        — requires WaveService
--   GameService          — requires WaveService, EconomyService
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.shared.framework)
local Logger    = require(replicated_storage.shared.logger)

-- ── Shared services (cross-place) ────────────────────────────────────────────
require(server_script_service.Common.ProfileDb)

-- ── Service registration (require triggers Framework.CreateService) ───────────

local services = server_script_service.Match.services
require(services.ZombieService)
require(services.EconomyService)
require(services.InventoryService)
require(services.WaveService)
require(services.CombatService)
require(services.PlayerService)
require(services.GameService)

-- ── Boot ─────────────────────────────────────────────────────────────────────

Logger.info("ServerRuntime", "Booting — 10 services registered.")
Framework.Start()
Logger.info("ServerRuntime", "Framework started. All services live.")
