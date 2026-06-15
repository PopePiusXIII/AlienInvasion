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
--   ZombieController    — no deps on other controllers
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)

-- ── Controller registration (require triggers Framework.CreateController) ─────

-- Because init.client.luau IS the "Client" LocalScript in the DataModel,
-- `script` refers to it directly and `script.controllers` is its child folder.
local controllers = script.controllers

require(controllers.CharacterController)  -- no deps
require(controllers.HudController)        -- requires CharacterController
require(controllers.GunController)        -- requires HudController
require(controllers.ShopController)       -- no deps
require(controllers.BoltController)       -- no deps
require(controllers.ZombieController)     -- no deps

-- ── Boot ─────────────────────────────────────────────────────────────────────

Logger.info("ClientRuntime", "Booting — 6 controllers registered.")
Framework.Start()
Logger.info("ClientRuntime", "Framework started. All controllers live.")

