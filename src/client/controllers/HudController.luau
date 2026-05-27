--!strict
--------------------------------------------------------------------------------
-- HudController.luau  (src/client/controllers)
-- Owns all in-game HUD: wave label, ammo counter, upgrade echo text.
-- Listens to WaveAnnounce and WaveClear, delegates stat boosts to
-- CharacterController. Single Responsibility: UI presentation only.
--
-- Public API:
--   HudController.setAmmoText(text, color)  — called by GunController
--   HudController.getScreenGui()            — called by LobbyController to parent its UI
--------------------------------------------------------------------------------

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework             = require(ReplicatedStorage.Shared.Framework)
local Logger                = require(ReplicatedStorage.Shared.Logger)
local Config                = require(ReplicatedStorage.Shared.Config)
local RemoteNames           = require(ReplicatedStorage.Shared.RemoteNames)
local CharacterController   = require(script.Parent.CharacterController)
local HudUpgradeEchoModule  = require(script.Parent.modules.hud.HudUpgradeEchoModule)

local TAG = "HudController"

local HudController = Framework.CreateController({ Name = TAG })

local _localPlayer = Players.LocalPlayer
local _screenGui:  ScreenGui
local _waveLabel:  TextLabel
local _ammoLabel:  TextLabel

-- ── Builder helpers ───────────────────────────────────────────────────────────
-- All UI is constructed programmatically here — no Studio explorer instances.

local function buildWaveLabel(parent: ScreenGui): TextLabel
	local label                  = Instance.new("TextLabel")
	label.Name                   = "WaveLabel"
	label.Size                   = UDim2.new(0.4, 0, 0.1, 0)
	label.Position               = UDim2.new(0.3, 0, 0.1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3             = Color3.new(1, 0.2, 0.2)
	label.TextScaled             = true
	label.Font                   = Enum.Font.GothamBold
	label.Text                   = ""
	label.Parent                 = parent
	return label
end

local function buildAmmoLabel(parent: ScreenGui): TextLabel
	local label                  = Instance.new("TextLabel")
	label.Name                   = "AmmoLabel"
	label.Size                   = UDim2.new(0.18, 0, 0.07, 0)
	label.Position               = UDim2.new(0.80, 0, 0.88, 0)
	label.BackgroundTransparency = 1
	label.TextColor3             = Color3.new(1, 1, 1)
	label.TextScaled             = true
	label.Font                   = Enum.Font.GothamBold
	label.Text                   = ""
	label.Parent                 = parent
	return label
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function HudController:Init()
	-- Create the ScreenGui here so it is owned once, never duplicated.
	_screenGui              = Instance.new("ScreenGui")
	_screenGui.Name         = "AlienInvasionHud"
	_screenGui.ResetOnSpawn = false
	_screenGui.Parent       = _localPlayer.PlayerGui

	_waveLabel = buildWaveLabel(_screenGui)
	_ammoLabel = buildAmmoLabel(_screenGui)

	Logger.info(TAG, "ScreenGui and HUD labels created.")
end

function HudController:Start()
	local waveAnnounceRemote = Framework.GetRemote(RemoteNames.WAVE_ANNOUNCE)
	local waveClearRemote    = Framework.GetRemote(RemoteNames.WAVE_CLEAR)

	-- Logger.wrapClientEvent: pcall-isolated + net trace when DEBUG_NETWORKING = true.
	Logger.wrapClientEvent(waveAnnounceRemote, TAG, function(waveNumber: number)
		_waveLabel.Text = "WAVE " .. tostring(waveNumber)
		task.delay(3, function()
			_waveLabel.Text = ""
		end)
	end)

	Logger.wrapClientEvent(waveClearRemote, TAG, function()
		-- Delegate state mutation to CharacterController — HudController never
		-- touches humanoid properties directly (clean separation of concerns).
		CharacterController.boostStat("walkSpeed",   Config.WAVE_CLEAR_SPEED_BOOST)
		CharacterController.boostStat("sprintSpeed", Config.WAVE_CLEAR_SPEED_BOOST)
		CharacterController.boostStat("scale",       Config.WAVE_CLEAR_SCALE_BOOST)

		local stats = CharacterController.getStats()
		Logger.info(TAG, "Stats upgraded — Walk: %.0f  Sprint: %.0f  Scale: %.2f",
			stats.walkSpeed, stats.sprintSpeed, stats.scale)

		HudUpgradeEchoModule.show(
			_screenGui,
			Config.WAVE_CLEAR_SPEED_BOOST,
			Config.WAVE_CLEAR_SCALE_BOOST
		)
	end)

	Logger.info(TAG, "Wave event listeners connected.")
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Called by GunController to update the ammo display.
--- Keeps ammo rendering decoupled from gun state logic.
function HudController.setAmmoText(text: string, color: Color3)
	if _ammoLabel then
		_ammoLabel.Text       = text
		_ammoLabel.TextColor3 = color
	end
end

--- Expose the ScreenGui so other controllers can parent their own UI into it.
function HudController.getScreenGui(): ScreenGui
	return _screenGui
end

return HudController
