--!strict
--------------------------------------------------------------------------------
-- LobbyServerRuntime.server.luau  (lobby/src/server)
-- THE single server entry point for the Lobby Place.
-- Requires all Lobby services and starts the framework.
-- NO game logic here — belongs in the appropriate service.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)

local services = script.Parent.services

require(services.MatchQueueService)        -- no deps
require(services.TeleportHelperService)    -- no deps
require(services.MatchmakingService)       -- requires MatchQueueService, TeleportHelperService
require(services.LightShowService)         -- no deps

Logger.info("LobbyServerRuntime", "Booting — 4 services registered.")
Framework.Start()
Logger.info("LobbyServerRuntime", "Framework started. All services live.")
