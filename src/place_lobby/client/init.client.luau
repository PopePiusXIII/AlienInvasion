--!strict
-- LobbyClientRuntime  (places/lobby/src/client/init.client.luau → StarterPlayerScripts.LobbyClient)
-- THE single client entry point for the Lobby Place.
-- Requires all Lobby controllers and boots the framework.
-- NO game logic here — belongs in MatchmakingController.
--
-- Because init.client.luau IS the "LobbyClient" LocalScript in the DataModel,
-- `script` refers to it directly and `script.controllers` is its child folder.
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")

local Framework = require(replicated_storage.common.shared.framework)
local Logger    = require(replicated_storage.common.shared.logger)

local controllers = script.controllers

require(controllers.LobbyHudController)
require(controllers.MatchmakingController)

Logger.info("LobbyClientRuntime", "Booting — 2 controllers registered.")
Framework.Start()
Logger.info("LobbyClientRuntime", "Framework started.")
