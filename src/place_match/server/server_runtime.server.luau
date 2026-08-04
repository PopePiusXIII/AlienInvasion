--!strict
-- ServerRuntime.server.luau (src/server)
-- THE single server entry point for the Match Place.

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")
local logger_config = 	replicated_storage.match.shared.configs.debug_config
local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger).new(logger_config)
local services = server_script_service.match.services

require(server_script_service.common.services.profile_db)
require(services.skill_service)
require(services.character_service)
require(services.health_service)
require(services.zombie_service)
require(services.economy_service)
require(services.inventory_service)
require(services.wave_service)
require(services.combat_service)
require(services.rng_service)
require(services.character_level_service)
require(services.game_service)

Logger.info("ServerRuntime", "Booting — 12 services registered.")
Framework.Start()
Logger.info("ServerRuntime", "Framework started. All services live.")
