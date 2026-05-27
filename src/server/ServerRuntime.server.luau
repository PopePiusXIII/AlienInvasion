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
--   WaveService          — requires ZombieService
--   CombatService        — requires ZombieService
--   DataService          — no deps
--   PlayerService        — requires WaveService, DataService
--   GameService          — requires WaveService, DataService
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)

-- ── Service registration (require triggers Framework.CreateService) ───────────

local services = script.Parent.services

require(services.PhysicsSetupService)
require(services.ZombieService)
require(services.WaveService)
require(services.CombatService)
require(services.DataService)
require(services.PlayerService)
require(services.GameService)

-- ── Boot ─────────────────────────────────────────────────────────────────────

Logger.info("ServerRuntime", "Booting — 7 services registered.")
Framework.Start()
Logger.info("ServerRuntime", "Framework started. All services live.")
