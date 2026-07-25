--!strict
-- ClientRuntime  (places/match/src/client/init.client.luau → StarterPlayerScripts.Client)
-- THE single client entry point for the Match Place.
--
-- Rule: NO game logic lives here. This file only requires controllers and boots
-- the framework. All logic belongs in the appropriate Controller module.
--
-- Controller require order (deps first):
--   CharacterController — no deps on other controllers
--   HudController       — requires CharacterController
--   GunController       — requires HudController
--   ShopController      — no deps on other controllers
--   BoltController      — no deps on other controllers
--   ZombieAnimationController — plays zombie walk/run animations
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")

local Framework = require(replicated_storage.common.shared.framework)
local Logger    = require(replicated_storage.common.shared.logger)

-- ── Controller registration (require triggers Framework.CreateController) ─────

-- Because init.client.luau IS the "Client" LocalScript in the DataModel,
-- `script` refers to it directly and `script.controllers` is its child folder.
local controllers = script.controllers

require(controllers.character_controller)      -- no deps
require(controllers.hud_controller)            -- requires CharacterController
require(controllers.inventory_controller)      -- custom inventory system
require(controllers.gun_controller)            -- requires HudController, InventoryController
-- ShopController removed
require(controllers.bolt_controller)           -- no deps
require(controllers.rng_controller)           -- RNG block controller
require(controllers.zombie_animation_controller) -- no deps

-- ── Boot ─────────────────────────────────────────────────────────────────────

Logger.info("ClientRuntime", "Booting — 7 controllers registered.")
Framework.Start()
Logger.info("ClientRuntime", "Framework started. All controllers live.")
