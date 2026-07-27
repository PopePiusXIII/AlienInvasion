--!strict
-- ClientRuntime (places/match/src/client/init.client.luau → StarterPlayerScripts.Client)
-- THE single client entry point for the Match Place.

local replicated_storage = game:GetService("ReplicatedStorage")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)

-- Use the ReplicatedStorage copies as the canonical controller modules. Other
-- controllers also require each other from this location, so requiring the
-- StarterPlayerScripts copies would register duplicate controllers.
local controllers = replicated_storage.match.client.controllers

require(controllers.character_controller)
require(controllers.hud_controller)
require(controllers.inventory_controller)
require(controllers.gun_controller)
require(controllers.bolt_controller)
require(controllers.rng_controller)
require(controllers.zombie_animation_controller)

Logger.info("ClientRuntime", "Booting — 7 controllers registered.")
Framework.Start()
Logger.info("ClientRuntime", "Framework started. All controllers live.")
