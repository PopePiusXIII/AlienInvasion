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
--   DataService          — no deps
--   EconomyService       — requires Config/RemoteNames
--   WaveService          — requires ZombieService, EconomyService, DataService
--   CombatService        — requires ZombieService, EconomyService
--   PlayerService        — requires WaveService, DataService
--   GameService          — requires WaveService, DataService, EconomyService
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)

-- ── Service registration (require triggers Framework.CreateService) ───────────

local services = script.Parent.services

require(services.PhysicsSetupService)
require(services.ZombieService)
require(services.DataService)
require(services.EconomyService)
require(services.WaveService)
require(services.CombatService)
require(services.PlayerService)
require(services.GameService)
require(services.FlyoverService)

-- ── Boot ─────────────────────────────────────────────────────────────────────

Logger.info("ServerRuntime", "Booting — 9 services registered.")
Framework.Start()
Logger.info("ServerRuntime", "Framework started. All services live.")
