--!strict
--------------------------------------------------------------------------------
-- HudController.luau  (src/client/controllers)
-- Owns the match-specific reactive Vide HUD.
-- Listens to WaveClear, delegates stat boosts to
-- CharacterController. Single Responsibility: UI presentation only.
--
-- Public API:
--   HudController.setActiveWeaponAmmo(current, max) — called by GunController
--   HudController.getScreenGui()            — called by LobbyController to parent its UI
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")

local Framework             = require(replicated_storage.common.shared.framework)
local Logger                = require(replicated_storage.common.shared.logger)
local WaveConfig            = require(replicated_storage.match.shared.configs.wave_config)
local RemoteNames           = require(replicated_storage.match.shared.remote_names)
local CharacterController   = require(replicated_storage.match.client.controllers.character_controller)
local InventoryController   = require(replicated_storage.match.client.controllers.inventory_controller)
local MatchHUD              = require(replicated_storage.match.ui.match_hud)
local HudUpgradeEchoModule  = require(replicated_storage.match.client.controllers.modules.hud.hud_upgrade_echo_module)

local TAG = "HudController"

local HudController = {}
HudController.Name = TAG

local _localPlayer = Players.LocalPlayer
local _screenGui:  ScreenGui
local _sources
-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function HudController:Init()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

	_screenGui = MatchHUD.gui
	_sources = MatchHUD.sources
	_screenGui.Parent = _localPlayer.PlayerGui

	Logger.info(TAG, "Match HUD parented to PlayerGui.")
end

local function onHealthUpdated(health: number, maxHealth: number)
	_sources.healthPercent(health / math.max(1, maxHealth) * 100)
end

local function onExperienceUpdated(level: number, currentExperience: number, requiredExperience: number)
	local normalizedRequiredExperience = math.max(1, math.floor(requiredExperience))
	local normalizedCurrentExperience = math.max(0, math.floor(currentExperience))
	_sources.currentXP(normalizedCurrentExperience)
	_sources.requiredXP(normalizedRequiredExperience)
	_sources.xpPercent(math.clamp(normalizedCurrentExperience / normalizedRequiredExperience, 0, 1))
end

local function onInventoryChanged(guns: { InventoryController.SyncedGun }, _equippedSlot: number?): ()
	local ammoTextByGun = table.clone(_sources.ammoTextByGun())
	local ammoColorByGun = table.clone(_sources.ammoColorByGun())
	local changed = false

	for _, gun in ipairs(guns) do
		if ammoTextByGun[gun.name] == nil then
			ammoTextByGun[gun.name] = string.format("%d / %d", gun.stats.magSize, gun.stats.max_ammo)
			ammoColorByGun[gun.name] = Color3.new()
			changed = true
		end
	end

	if changed then
		_sources.ammoTextByGun(ammoTextByGun)
		_sources.ammoColorByGun(ammoColorByGun)
	end
	_sources.guns(guns)
end

local function setGunAmmoText(gunName: string, text: string)
	local ammoTextByGun = table.clone(_sources.ammoTextByGun())
	ammoTextByGun[gunName] = text
	_sources.ammoTextByGun(ammoTextByGun)
end

local function setGunAmmoColor(gunName: string, color: Color3)
	local ammoColorByGun = table.clone(_sources.ammoColorByGun())
	ammoColorByGun[gunName] = color
	_sources.ammoColorByGun(ammoColorByGun)
end

function HudController:Start()
	local waveClearRemote = Framework.GetRemote(RemoteNames.WAVE_CLEAR)
	local healthUpdatedRemote = Framework.GetRemote(RemoteNames.PLAYER_HEALTH_UPDATED)
	local experienceUpdatedRemote = Framework.GetRemote(RemoteNames.EXPERIENCE_UPDATED)

	Logger.onClientEvent(waveClearRemote, TAG, function()
		-- Delegate state mutation to CharacterController — HudController never
		-- touches humanoid properties directly (clean separation of concerns).
		CharacterController.boostStat("walkSpeed",   WaveConfig.WAVE_CLEAR_SPEED_BOOST)
		CharacterController.boostStat("sprintSpeed", WaveConfig.WAVE_CLEAR_SPEED_BOOST)
		CharacterController.boostStat("scale",       WaveConfig.WAVE_CLEAR_SCALE_BOOST)

		local stats = CharacterController.getStats()
		Logger.info(TAG, "Stats upgraded — Walk: %.0f  Sprint: %.0f  Scale: %.2f",
			stats.walkSpeed, stats.sprintSpeed, stats.scale)

		HudUpgradeEchoModule.show(
			_screenGui,
			WaveConfig.WAVE_CLEAR_SPEED_BOOST,
			WaveConfig.WAVE_CLEAR_SCALE_BOOST
		)
	end)

	Logger.onClientEvent(healthUpdatedRemote, TAG, onHealthUpdated)
	Logger.onClientEvent(experienceUpdatedRemote, TAG, onExperienceUpdated)
	InventoryController.onInventoryChanged(onInventoryChanged)
	onInventoryChanged(InventoryController.getGuns(), InventoryController.getEquippedSlot())

	Logger.info(TAG, "HUD event listeners connected.")
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Called by GunController to update one weapon's ammo display.
function HudController.setAmmoText(gunName: string, text: string, color: Color3)
	setGunAmmoText(gunName, text)
	setGunAmmoColor(gunName, color)
end

--- Called by GunController to update one weapon's numeric ammo display.
function HudController.setActiveWeaponAmmo(gunName: string, current: number, maxMag: number)
	setGunAmmoText(gunName, string.format("%d/%d", current, maxMag))
end

--- Expose the ScreenGui so other controllers can parent their own UI into it.
function HudController.getScreenGui(): ScreenGui
	return _screenGui
end

Framework.CreateController(HudController)
return HudController
