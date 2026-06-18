--!strict
--------------------------------------------------------------------------------
-- LobbyHudController.luau  (places/lobby/src/client/controllers)
-- Owns all lobby UI via reactive vide components:
--   - LobbyMainHUD    — always-on title, player name, silver, hint text
--   - LobbyHUD        — matchmaking panel (show/hide near pad)
--
-- Single Responsibility: UI presentation only.
-- Queue state and remote logic belongs in MatchmakingController.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework  = require(ReplicatedStorage.Shared.Framework)
local Logger     = require(ReplicatedStorage.Shared.Logger)
local LobbyMainHUD = require(ReplicatedStorage.Shared.vide.LobbyMainHUD)
local LobbyHUD     = require(ReplicatedStorage.Shared.vide.LobbyHUD)

local TAG = "LobbyHudController"

local LobbyHudController = Framework.CreateController({ Name = TAG })

-- Main HUD (always visible)
local _mainScreenGui: Instance
local _mainControls:  { setSilver: (number) -> (), setHint: (string) -> () }

-- Matchmaking panel (shown/hidden by proximity)
local _matchScreenGui: Instance
local _matchControls:   { setVisible: (boolean) -> (), setStatus: (string) -> (), setButton: (string, boolean) -> () }

-- Callbacks set by MatchmakingController so the HUD can delegate button clicks back.
local _onFindMatchClicked: () -> () = function() end
local _onShopClicked:      () -> () = function() end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function LobbyHudController:Init()
	-- Always-on lobby HUD
	_mainScreenGui, _mainControls = LobbyMainHUD.createLobbyMainHUD({
		title    = "ALIEN INVASION",
		hintText = "Walk to a pad to play",
	})
	_mainScreenGui.Parent = Players.LocalPlayer.PlayerGui

	-- Matchmaking panel (initially hidden)
	_matchScreenGui, _matchControls = LobbyHUD.createLobbyHUD({
		title      = "ALIEN INVASION",
		statusText = "Click FIND MATCH to enter the queue.",
		buttonText = "FIND MATCH",
		onButtonClicked = function()
			_onFindMatchClicked()
		end,
		onShopClicked = function()
			_onShopClicked()
		end,
	})
	_matchScreenGui.Parent = Players.LocalPlayer.PlayerGui

	Logger.info(TAG, "Both lobby HUDs created via vide.")
end

-- ── Public API — called by MatchmakingController ──────────────────────────────

--- Register the callback for the Find Match / Cancel button.
function LobbyHudController.setFindMatchCallback(cb: () -> ())
	_onFindMatchClicked = cb
end

--- Register the callback for the Shop button.
function LobbyHudController.setShopCallback(cb: () -> ())
	_onShopClicked = cb
end

--- Show or hide the matchmaking panel.
function LobbyHudController.setPanelVisible(visible: boolean)
	_matchControls.setVisible(visible)
end

--- Update the status text on the matchmaking panel.
function LobbyHudController.setStatus(msg: string)
	_matchControls.setStatus(msg)
end

--- Update the button text and enabled state.
function LobbyHudController.setButtonText(text: string, enabled: boolean)
	_matchControls.setButton(text, enabled)
end

--- Hide the matchmaking panel entirely (e.g. during teleport countdown).
function LobbyHudController.hidePanel()
	_matchControls.setVisible(false)
end

--- Update silver balance on the main HUD.
function LobbyHudController.setSilver(amount: number)
	_mainControls.setSilver(amount)
end

--- Update the navigation hint text.
function LobbyHudController.setHint(msg: string)
	_mainControls.setHint(msg)
end

return LobbyHudController
