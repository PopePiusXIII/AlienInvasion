--!strict
--------------------------------------------------------------------------------
-- LobbyController.luau  (src/client/controllers)
-- Manages the proximity-based GoToGame pad detection and the Play prompt UI.
-- Single Responsibility: lobby interaction only.
-- Fires RequestPlay via Logger.fireServer (net trace enabled).
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework     = require(ReplicatedStorage.Shared.Framework)
local Logger        = require(ReplicatedStorage.Shared.Logger)
local Config        = require(ReplicatedStorage.Shared.Config)
local RemoteNames   = require(ReplicatedStorage.Shared.RemoteNames)
local HudController = require(script.Parent.HudController)
local LobbyPromptViewModule = require(script.Parent.modules.lobby.LobbyPromptViewModule)
local PadProximityModule = require(script.Parent.modules.lobby.PadProximityModule)

local TAG = "LobbyController"

local LobbyController = Framework.CreateController({ Name = TAG })

local _localPlayer  = Players.LocalPlayer
local _character:   Model?  = nil
local _requestPlayRemote: RemoteEvent

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function LobbyController:Init()
	_localPlayer.CharacterAdded:Connect(function(newCharacter: Model)
		_character = newCharacter
	end)
	if _localPlayer.Character then
		_character = _localPlayer.Character
	end

	Logger.info(TAG, "Initialized.")
end

function LobbyController:Start()
	_requestPlayRemote = Framework.GetRemote(RemoteNames.REQUEST_PLAY)

	-- Parent the prompt into the shared ScreenGui owned by HudController.
	local playPrompt = LobbyPromptViewModule.buildPlayPrompt(HudController.getScreenGui())

	-- Run the proximity watcher in a separate thread (waitForGamePad may yield).
	task.spawn(function()
		PadProximityModule.start(
			playPrompt,
			_localPlayer,
			Config.LOBBY_PAD_NAME,
			function() return _character end,
			function()
				Logger.fireServer(_requestPlayRemote)
				Logger.info(TAG, "RequestPlay fired.")
			end
		)
	end)

	Logger.info(TAG, "RequestPlay remote acquired; proximity watcher started.")
end

return LobbyController
