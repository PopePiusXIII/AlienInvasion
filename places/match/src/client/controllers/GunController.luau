--!strict
--------------------------------------------------------------------------------
-- GunController.luau  (src/client/controllers)
-- Manages gun equip, fire, and reload on the client.
-- Reports confirmed hits to the server via the ShootGun RemoteEvent.
-- Visual effects (muzzle flash, particles) play locally; damage is server-auth.
--
-- Single Responsibility: gun input handling and local visual feedback.
-- Ammo display is delegated to HudController.setAmmoText() — no direct UI here.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework     = require(ReplicatedStorage.Shared.Framework)
local Logger        = require(ReplicatedStorage.Shared.Logger)
local Config        = require(ReplicatedStorage.Shared.Config)
local RemoteNames   = require(ReplicatedStorage.Shared.RemoteNames)
local HudController = require(script.Parent.HudController)
local GunCatalogModule = require(script.Parent.modules.gun.GunCatalogModule)
local GunFxModule = require(script.Parent.modules.gun.GunFxModule)
local GunHitScanModule = require(script.Parent.modules.gun.GunHitScanModule)

local TAG = "GunController"

local GunController = Framework.CreateController({ Name = TAG })

local _localPlayer  = Players.LocalPlayer
local _mouse        = _localPlayer:GetMouse()
local _shootRemote: RemoteEvent

-- Gun state — all mutable locals are module-private.
local _isReloading:      boolean              = false
local _isOnFireCooldown: boolean              = false
local _isTriggerHeld:    boolean              = false
local _isAutoFiring:     boolean              = false
local _equippedGun:      Tool?                = nil
local _activatedConn:    RBXScriptConnection? = nil
local _deactivatedConn:  RBXScriptConnection? = nil
local _aimPitchConn:     RBXScriptConnection? = nil
local _ammoByGun:        { [string]: number } = {}
local _baseGunGrip:      CFrame?              = nil
local _cachedMuzzle:     BasePart?            = nil
local _cachedHrp:        BasePart?            = nil

local MAX_VERTICAL_AIM_RADIANS = math.rad(35)

type GunStats = {
	damage: number,
	range: number,
	fireCooldown: number,
	magSize: number,
	reloadTime: number,
	isAutomatic: boolean,
	tracer: GunCatalogModule.GunTracerStyle,
}

local function getGunStats(gunName: string?): GunStats
	return GunCatalogModule.getGunStats(Config, gunName) :: GunStats
end

local function isSupportedGunName(name: string): boolean
	return GunCatalogModule.isSupportedGunName(Config, name)
end

local function getCurrentAmmo(): number
	if not _equippedGun then return 0 end
	local gunName = _equippedGun.Name
	local stats = getGunStats(gunName)
	if _ammoByGun[gunName] == nil then
		_ammoByGun[gunName] = stats.magSize
	end
	return _ammoByGun[gunName]
end

local function setCurrentAmmo(value: number)
	if not _equippedGun then return end
	_ammoByGun[_equippedGun.Name] = value
end

-- ── Private helpers ───────────────────────────────────────────────────────────

local function refreshAmmoDisplay()
	local stats = getGunStats(_equippedGun and _equippedGun.Name or nil)
	local ammo = getCurrentAmmo()
	if not _equippedGun then
		HudController.setAmmoText("", Color3.new(1, 1, 1))
		return
	end
	if _isReloading then
		HudController.setAmmoText("RELOADING...", Color3.new(1, 0.6, 0))
		return
	end
	local color = ammo > 0 and Color3.new(1, 1, 1) or Color3.new(1, 0.2, 0.2)
	HudController.setAmmoText(string.format("%d / %d", ammo, stats.magSize), color)
end

local function reload()
	if not _equippedGun then return end
	local reloadingGun = _equippedGun
	local stats = getGunStats(reloadingGun.Name)
	if _isReloading or getCurrentAmmo() == stats.magSize then return end
	_isReloading = true
	refreshAmmoDisplay()
	task.wait(stats.reloadTime)
	if _equippedGun and _equippedGun == reloadingGun then
		setCurrentAmmo(stats.magSize)
	end
	_isReloading = false
	refreshAmmoDisplay()
end

local function castShot(origin: Vector3): (Vector3, Model?)
	local stats = getGunStats(_equippedGun and _equippedGun.Name or nil)
	local result = GunHitScanModule.castShot(_mouse, _localPlayer.Character, origin, stats.range)
	return result.hitPosition, result.hitZombie
end

local function fire(): boolean
	local stats = getGunStats(_equippedGun and _equippedGun.Name or nil)
	local character = _localPlayer.Character
	if _isOnFireCooldown or _isReloading or not _equippedGun or not character then return false end

	local hrp = _cachedHrp
	if not hrp then return false end

	local ammo = getCurrentAmmo()
	if ammo <= 0 then
		task.spawn(reload)
		return false
	end

	_isOnFireCooldown = true
	setCurrentAmmo(ammo - 1)
	refreshAmmoDisplay()

	local origin: Vector3 = _cachedMuzzle and _cachedMuzzle.Position or (hrp :: BasePart).Position
	local hitPosition, hitZombie = castShot(origin)

	GunFxModule.playShootSound()
	GunFxModule.drawTracer(origin, hitPosition, stats.tracer)
	GunFxModule.flashMuzzle(Config.GUN_MUZZLE_DELAY)

	-- Logger.fireServer provides the net trace hook when DEBUG_NETWORKING = true.
	Logger.fireServer(_shootRemote, hitZombie, _equippedGun.Name)

	task.wait(stats.fireCooldown)
	_isOnFireCooldown = false
	return true
end

local function startAutoFire(gun: Tool)
	if _isAutoFiring then return end
	_isAutoFiring = true

	task.spawn(function()
		while _isAutoFiring and _isTriggerHeld and _equippedGun == gun do
			if not fire() then
				task.wait(0.05)
			end
		end
		_isAutoFiring = false
	end)
end

local function stopTriggerFiring()
	_isTriggerHeld = false
	_isAutoFiring = false
end

local function onGunActivated(gun: Tool)
	if _equippedGun ~= gun then return end

	local stats = getGunStats(gun.Name)
	_isTriggerHeld = true

	if stats.isAutomatic then
		startAutoFire(gun)
		return
	end

	fire()
end

local function stopAimPitchTracking()
	if _aimPitchConn then
		_aimPitchConn:Disconnect()
		_aimPitchConn = nil
	end

	if _equippedGun and _baseGunGrip then
		_equippedGun.Grip = _baseGunGrip
	end

	_baseGunGrip = nil
end

local function startAimPitchTracking(gun: Tool)
	stopAimPitchTracking()
	_baseGunGrip = gun.Grip

	_aimPitchConn = RunService.RenderStepped:Connect(function()
		if _equippedGun ~= gun then return end
		local hrp = _cachedHrp
		if not hrp then return end

		local toMouse = _mouse.Hit.Position - hrp.Position
		local horizontal = Vector3.new(toMouse.X, 0, toMouse.Z)
		if horizontal.Magnitude < 0.001 then return end

		local pitch = math.atan2(toMouse.Y, horizontal.Magnitude)
		pitch = math.clamp(pitch, -MAX_VERTICAL_AIM_RADIANS, MAX_VERTICAL_AIM_RADIANS)

		gun.Grip = (_baseGunGrip :: CFrame) * CFrame.Angles(-pitch, 0, 0)
	end)
end

local function onCharacterAdded(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	_cachedHrp = (hrp and hrp:IsA("BasePart")) and hrp :: BasePart or nil
end

local function onCharacterRemoving()
	_cachedHrp = nil
end

local function onGunEquipped(gun: Tool)
	_equippedGun      = gun
	local stats = getGunStats(gun.Name)
	if _ammoByGun[gun.Name] == nil then
		_ammoByGun[gun.Name] = stats.magSize
	end
	_isReloading      = false
	_isOnFireCooldown = false
	stopTriggerFiring()
	_activatedConn    = gun.Activated:Connect(function()
		onGunActivated(gun)
	end)
	_deactivatedConn  = gun.Deactivated:Connect(stopTriggerFiring)
	local m = gun:FindFirstChild("Muzzle", true)
	_cachedMuzzle = (m and m:IsA("BasePart")) and m :: BasePart or nil
	GunFxModule.onGunEquipped(gun)
	startAimPitchTracking(gun)
	refreshAmmoDisplay()
end

local function onGunUnequipped()
	if _activatedConn then
		_activatedConn:Disconnect()
		_activatedConn = nil
	end
	if _deactivatedConn then
		_deactivatedConn:Disconnect()
		_deactivatedConn = nil
	end
	stopTriggerFiring()
	stopAimPitchTracking()
	_cachedMuzzle = nil
	GunFxModule.onGunUnequipped()
	_equippedGun = nil
	refreshAmmoDisplay()
end

-- Watch a character model for the gun being equipped (moved into character)
-- or unequipped (moved out). Uses ChildAdded/ChildRemoved on the character
-- so it catches both initial equip and hotswap.
local function watchCharacter(character: Model)
	-- Check if gun is already equipped (e.g. character respawned mid-session).
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and isSupportedGunName(child.Name) then
			onGunEquipped(child :: Tool)
		end
	end

	character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") and isSupportedGunName(child.Name) then
			onGunEquipped(child :: Tool)
		end
	end)

	character.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Tool") and isSupportedGunName(child.Name) then
			onGunUnequipped()
		end
	end)
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function GunController:Init()
	Logger.info(TAG, "Initialized.")
end

function GunController:Start()
	-- GetRemote yields until the server's WaveService:Init() has created the remote.
	_shootRemote = Framework.GetRemote(RemoteNames.SHOOT_GUN)

	_localPlayer.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(character)
		watchCharacter(character)
	end)
	_localPlayer.CharacterRemoving:Connect(onCharacterRemoving)
	if _localPlayer.Character then
		onCharacterAdded(_localPlayer.Character)
		watchCharacter(_localPlayer.Character)
	end

	-- R key manual reload.
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.R then
			task.spawn(reload)
		end
	end)

	Logger.info(TAG, "ShootGun remote acquired; gun watchers connected.")
end

return GunController
