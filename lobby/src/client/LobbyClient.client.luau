--!strict
--------------------------------------------------------------------------------
-- LobbyClientRuntime  (lobby/src/client/LobbyClient.client.luau)
-- THE single client entry point for the Lobby Place.
-- Requires all Lobby controllers and boots the framework.
-- NO game logic here — belongs in MatchmakingController.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)

local controllers = script.Parent.controllers

require(controllers.MatchmakingController)

Logger.info("LobbyClientRuntime", "Booting — 1 controller registered.")
Framework.Start()
Logger.info("LobbyClientRuntime", "Framework started.")
