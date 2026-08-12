--!strict
--------------------------------------------------------------------------------
-- LobbyController.luau  (src/client/controllers)
-- Manages the proximity-based GoToGame pad detection and the Play prompt UI.
-- Single Responsibility: lobby interaction only.
-- Fires RequestPlay via Logger.fireServer (net trace enabled).
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")

local Framework     = require(replicated_storage.common.shared.framework)
local Logger        = require(replicated_storage.common.shared.logger)
local Config        = require(replicated_storage.match.shared.configs.game_config)
local HudController = require(replicated_storage.match.client.controllers.hud_controller)
local LobbyPromptViewModule = require(replicated_storage.match.client.controllers.modules.lobby.lobby_prompt_view_module)
local PadProximityModule = require(replicated_storage.match.client.controllers.modules.lobby.pad_proximity_module)

local TAG = "LobbyController"

local LobbyController = {}
LobbyController.Name = TAG

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
	_requestPlayRemote = Framework.GetRemote("RequestPlay")

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

Framework.CreateController(LobbyController)
return LobbyController
