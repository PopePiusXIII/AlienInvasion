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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework     = require(ReplicatedStorage.Shared.Framework)
local Logger        = require(ReplicatedStorage.Shared.Logger)
local Config        = require(ReplicatedStorage.Shared.Config)
local RemoteNames   = require(ReplicatedStorage.Shared.RemoteNames)
local HudController = require(script.Parent.HudController)

local TAG = "GunController"

local GunController = Framework.CreateController({ Name = TAG })

local _localPlayer  = Players.LocalPlayer
local _mouse        = _localPlayer:GetMouse()
local _shootRemote: RemoteEvent

-- Gun state — all mutable locals are module-private.
local _ammo:             number               = Config.GUN_MAG_SIZE
local _isReloading:      boolean              = false
local _isOnFireCooldown: boolean              = false
local _equippedGun:      Tool?                = nil
local _activatedConn:    RBXScriptConnection? = nil

-- ── Private helpers ───────────────────────────────────────────────────────────

local function refreshAmmoDisplay()
	if not _equippedGun then
		HudController.setAmmoText("", Color3.new(1, 1, 1))
		return
	end
	if _isReloading then
		HudController.setAmmoText("RELOADING...", Color3.new(1, 0.6, 0))
		return
	end
	local color = _ammo > 0 and Color3.new(1, 1, 1) or Color3.new(1, 0.2, 0.2)
	HudController.setAmmoText(string.format("%d / %d", _ammo, Config.GUN_MAG_SIZE), color)
end

local function reload()
	if _isReloading or not _equippedGun or _ammo == Config.GUN_MAG_SIZE then return end
	_isReloading = true
	refreshAmmoDisplay()
	task.wait(Config.GUN_RELOAD_TIME)
	if _equippedGun then
		_ammo = Config.GUN_MAG_SIZE
	end
	_isReloading = false
	refreshAmmoDisplay()
end

local function flashMuzzle(gun: Tool)
	local muzzle = gun:FindFirstChild("Muzzle", true)
	if not muzzle then return end
	local flash = muzzle:FindFirstChild("FlashLight")
	if flash and flash:IsA("PointLight") then
		(flash :: PointLight).Enabled = true
		task.delay(Config.GUN_MUZZLE_DELAY, function()
			(flash :: PointLight).Enabled = false
		end)
	end
	local particles = muzzle:FindFirstChildWhichIsA("ParticleEmitter")
	if particles then
		(particles :: ParticleEmitter):Emit(8)
	end
end

local function findHitZombie(origin: Vector3): Model?
	local character = _localPlayer.Character
	local direction = (_mouse.Hit.Position - origin).Unit * Config.GUN_RANGE
	local params    = RaycastParams.new()
	if character then
		params.FilterDescendantsInstances = { character }
	end
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, direction, params)
	if not result then return nil end

	local ancestor = result.Instance:FindFirstAncestorOfClass("Model")
	return (ancestor and ancestor.Name == "Zombie") and ancestor :: Model or nil
end

local function fire()
	local character = _localPlayer.Character
	if _isOnFireCooldown or _isReloading or not _equippedGun or not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then return end

	if _ammo <= 0 then
		task.spawn(reload)
		return
	end

	_isOnFireCooldown = true
	_ammo -= 1
	refreshAmmoDisplay()

	local muzzle = _equippedGun:FindFirstChild("Muzzle", true)
	local origin: Vector3 = (muzzle and muzzle:IsA("BasePart"))
		and (muzzle :: BasePart).WorldPosition
		or  (hrp :: BasePart).Position

	flashMuzzle(_equippedGun)

	-- Logger.fireServer provides the net trace hook when DEBUG_NETWORKING = true.
	Logger.fireServer(_shootRemote, findHitZombie(origin))

	task.wait(Config.GUN_FIRE_COOLDOWN)
	_isOnFireCooldown = false
end

local function onGunEquipped(gun: Tool)
	_equippedGun      = gun
	_ammo             = Config.GUN_MAG_SIZE
	_isReloading      = false
	_isOnFireCooldown = false
	_activatedConn    = gun.Activated:Connect(fire)
	refreshAmmoDisplay()
end

local function onGunUnequipped()
	if _activatedConn then
		_activatedConn:Disconnect()
		_activatedConn = nil
	end
	_equippedGun = nil
	refreshAmmoDisplay()
end

-- Watch a character model for the gun being equipped (moved into character)
-- or unequipped (moved out). Uses ChildAdded/ChildRemoved on the character
-- so it catches both initial equip and hotswap.
local function watchCharacter(character: Model)
	-- Check if gun is already equipped (e.g. character respawned mid-session).
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child.Name == Config.GUN_NAME then
			onGunEquipped(child :: Tool)
		end
	end

	character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") and child.Name == Config.GUN_NAME then
			onGunEquipped(child :: Tool)
		end
	end)

	character.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Tool") and child.Name == Config.GUN_NAME then
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

	_localPlayer.CharacterAdded:Connect(watchCharacter)
	if _localPlayer.Character then
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
