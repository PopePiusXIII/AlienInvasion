--!strict
-- LobbyClientRuntime  (places/lobby/src/client/init.client.luau → StarterPlayerScripts.LobbyClient)
-- THE single client entry point for the Lobby Place.
-- Requires all Lobby controllers and boots the framework.
-- NO game logic here — belongs in MatchmakingController.
--
-- Because init.client.luau IS the "LobbyClient" LocalScript in the DataModel,
-- `script` refers to it directly and `script.controllers` is its child folder.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)

local controllers = script.controllers

require(controllers.CharacterController)
require(controllers.LobbyHudController)
require(controllers.MatchmakingController)

Logger.info("LobbyClientRuntime", "Booting — 3 controllers registered.")
Framework.Start()
Logger.info("LobbyClientRuntime", "Framework started.")
