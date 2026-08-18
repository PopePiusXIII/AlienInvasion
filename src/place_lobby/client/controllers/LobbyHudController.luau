--!strict
--------------------------------------------------------------------------------
-- LobbyHudController.luau  (places/lobby/src/client/controllers)
-- Owns all lobby UI via reactive vide components:
--   - LobbyMainHUD    — always-on title, player name, silver, hint text
--   - LobbyHUD        — matchmaking panel (created/destroyed on proximity)
--
-- Single Responsibility: UI presentation only.
-- Queue state and remote logic belongs in MatchmakingController.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")

local Framework  = require(replicated_storage.common.shared.framework)
local Logger     = require(replicated_storage.common.shared.logger)
local LobbyMainHUD = require(replicated_storage.common.shared.vide.lobby_main_hud)
local MatchmakingHUDModule = require(replicated_storage.common.shared.vide.matchmaking_hud)
local LobbyHudController = { Name = "LobbyHudController" }

local TAG = "LobbyHudController"

-- Main HUD (always visible)
local _mainScreenGui: ScreenGui
local _sources

-- Matchmaking panel (lazily created when player enters matchmaking area)
local _matchScreenGui:   Instance?
local _matchControls:    { setVisible: (boolean) -> (), setStatus: (string) -> (), setButton: (string, boolean) -> () }?
local _isMatchPanelActive = false

-- Callbacks set by MatchmakingController so the HUD can delegate button clicks back.
local function doNothing() end

local _onFindMatchClicked: () -> () = doNothing
local _onShopClicked:      () -> () = doNothing

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function LobbyHudController:Init()
	_mainScreenGui = LobbyMainHUD.gui
	_sources = LobbyMainHUD.sources
	_mainScreenGui.Parent = Players.LocalPlayer.PlayerGui
end

local function onCurrencyUpdated(silverAmount: number, goldAmount: number)
	_sources.silverAmount(silverAmount)
	_sources.goldAmount(goldAmount)
end

function LobbyHudController:Start()
	local currencyUpdatedRemote = Framework.GetRemote("LobbyCurrencyUpdated")
	Logger.onClientEvent(currencyUpdatedRemote, TAG, onCurrencyUpdated)
end

-- ── Matchmaking panel lifecycle ──────────────────────────────────────────────

local function onMatchButtonClicked()
	_onFindMatchClicked()
end

local function onShopButtonClicked()
	_onShopClicked()
end

local function createMatchPanel()
	if _isMatchPanelActive then return end
	_isMatchPanelActive = true

	local player = assert(Players.LocalPlayer, "LobbyHudController requires a local player")
	local screenGui, controls = MatchmakingHUDModule.createMatchmakingHUD({
		title = "ALIEN INVASION",
		statusText = "Click FIND MATCH to enter the queue.",
		buttonText = "FIND MATCH",
		onButtonClicked = onMatchButtonClicked,
		onShopClicked = onShopButtonClicked,
	})

	_matchScreenGui = screenGui
	_matchControls = controls
	screenGui.Parent = player.PlayerGui
	Logger.info(TAG, "Matchmaking panel created.")
end

local function destroyMatchPanel()
	if not _isMatchPanelActive then return end
	_isMatchPanelActive = false

	if _matchScreenGui then
		_matchScreenGui:Destroy()
	end
	_matchScreenGui = nil
	_matchControls = nil
	Logger.info(TAG, "Matchmaking panel destroyed.")
end

-- ── Public API — called by MatchmakingController ─────────────────────────────

function LobbyHudController.setFindMatchCallback(callback: () -> ())
	_onFindMatchClicked = callback
end

function LobbyHudController.setShopCallback(callback: () -> ())
	_onShopClicked = callback
end

function LobbyHudController.setPanelVisible(visible: boolean)
	if visible then
		createMatchPanel()
		if _matchControls then
			_matchControls.setVisible(true)
		end
	elseif _isMatchPanelActive and _matchControls then
		_matchControls.setVisible(false)
	end
end

function LobbyHudController.setStatus(message: string)
	if _matchControls then
		_matchControls.setStatus(message)
	end
end

function LobbyHudController.setButtonText(text: string, enabled: boolean)
	if _matchControls then
		_matchControls.setButton(text, enabled)
	end
end

function LobbyHudController.hidePanel()
	destroyMatchPanel()
end

Framework.CreateController(LobbyHudController)

return LobbyHudController
