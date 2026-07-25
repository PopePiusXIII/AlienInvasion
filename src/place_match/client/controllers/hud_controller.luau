--!strict
--------------------------------------------------------------------------------
-- HudController.luau  (src/client/controllers)
-- Owns all in-game HUD via the reactive vide MatchHUD component.
-- Listens to WaveAnnounce and WaveClear, delegates stat boosts to
-- CharacterController. Single Responsibility: UI presentation only.
--
-- Public API:
--   HudController.setAmmoText(text, color)  — called by GunController
--   HudController.getScreenGui()            — called by LobbyController to parent its UI
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework             = require(ReplicatedStorage.Shared.Framework)
local Logger                = require(ReplicatedStorage.Shared.Logger)
local Config                = require(ReplicatedStorage.Shared.Config)
local RemoteNames           = require(ReplicatedStorage.Shared.RemoteNames)
local CharacterController   = require(script.Parent.CharacterController)
local InventoryController   = require(script.Parent.InventoryController)
local MatchHUD              = require(ReplicatedStorage.Shared.vide.MatchHUD)
local HudUpgradeEchoModule  = require(script.Parent.modules.hud.HudUpgradeEchoModule)

local TAG = "HudController"

local HudController = Framework.CreateController({ Name = TAG })

local _localPlayer = Players.LocalPlayer
local _screenGui:  ScreenGui
local _controls
local _unmount: () -> ()
-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function HudController:Init()
	_screenGui              = Instance.new("ScreenGui")
	_screenGui.Name         = "AlienInvasionHud"
	_screenGui.ResetOnSpawn = false
	_screenGui.Parent       = _localPlayer.PlayerGui

	local inventorySize = Config.INVENTORY_SIZE or 2
	_controls, _unmount = MatchHUD.createMatchHUD({ 
		parentGui = _screenGui,
		inventorySize = inventorySize,
	})

	Logger.info(TAG, "ScreenGui created; MatchHUD mounted via vide.")
end

function HudController:Start()
	local waveAnnounceRemote = Framework.GetRemote(RemoteNames.WAVE_ANNOUNCE)
	local waveClearRemote    = Framework.GetRemote(RemoteNames.WAVE_CLEAR)
	local runCurrencyRemote  = Framework.GetRemote(RemoteNames.RUN_CURRENCY_UPDATED)

	-- Logger.wrapClientEvent: pcall-isolated + net trace when DEBUG_NETWORKING = true.
	Logger.wrapClientEvent(waveAnnounceRemote, TAG, function(waveNumber: number)
		_controls.setWaveText("WAVE " .. tostring(waveNumber))
		task.delay(3, function()
			_controls.clearWaveText()
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

	Logger.wrapClientEvent(runCurrencyRemote, TAG, function(silverStuds: number, goldEarned: number)
		_controls.setSilverAmount(silverStuds)
		_controls.setGoldAmount(goldEarned or 0)
	end)
	
	-- Listen to inventory changes and update the HUD
	InventoryController.onInventoryChanged(function(weapons: { string }, equippedSlot: number?)
		_controls.setInventory(weapons, equippedSlot)
	end)

	Logger.info(TAG, "Wave event listeners connected.")
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Called by GunController to update the ammo display.
--- Keeps ammo rendering decoupled from gun state logic.
function HudController.setAmmoText(text: string, color: Color3)
	_controls.setAmmoText(text, color)
end

--- Expose the ScreenGui so other controllers can parent their own UI into it.
function HudController.getScreenGui(): ScreenGui
	return _screenGui
end

return HudController
