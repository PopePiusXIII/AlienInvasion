--!strict

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local localPlayer = Players.LocalPlayer
local mouse       = localPlayer:GetMouse()

local GunManager = {}

local ammoLabel: TextLabel    = nil :: any
local shootEvent: RemoteEvent = nil :: any

local ammo: number                        = Config.GUN_MAG_SIZE
local isReloading: boolean                = false
local isOnFireCooldown: boolean           = false
local equippedGun: Tool?                  = nil
local activatedConn: RBXScriptConnection? = nil

local function refreshAmmoDisplay()
	if not equippedGun then
		ammoLabel.Text = ""
		return
	end
	if isReloading then
		ammoLabel.Text       = "RELOADING..."
		ammoLabel.TextColor3 = Color3.new(1, 0.6, 0)
		return
	end
	ammoLabel.Text       = ammo .. " / " .. Config.GUN_MAG_SIZE
	ammoLabel.TextColor3 = ammo > 0 and Color3.new(1, 1, 1) or Color3.new(1, 0.2, 0.2)
end

local function reload()
	if isReloading or not equippedGun or ammo == Config.GUN_MAG_SIZE then return end
	isReloading = true
	refreshAmmoDisplay()
	task.wait(Config.GUN_RELOAD_TIME)
	if equippedGun then
		ammo = Config.GUN_MAG_SIZE
	end
	isReloading = false
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
	local character = localPlayer.Character
	local direction = (mouse.Hit.Position - origin).Unit * Config.GUN_RANGE
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
	local character = localPlayer.Character
	if isOnFireCooldown or isReloading or not equippedGun or not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then return end
	local rootPart = hrp :: BasePart

	if ammo <= 0 then
		task.spawn(reload)
		return
	end

	isOnFireCooldown = true
	ammo -= 1
	refreshAmmoDisplay()

	local muzzle = equippedGun:FindFirstChild("Muzzle", true)
	local origin: Vector3 = (muzzle and muzzle:IsA("BasePart"))
		and (muzzle :: BasePart).WorldPosition
		or  rootPart.Position

	flashMuzzle(equippedGun)
	shootEvent:FireServer(findHitZombie(origin))

	task.wait(Config.GUN_FIRE_COOLDOWN)
	isOnFireCooldown = false
end

local function onGunEquipped(gun: Tool)
	equippedGun      = gun
	ammo             = Config.GUN_MAG_SIZE
	isReloading      = false
	isOnFireCooldown = false
	activatedConn    = gun.Activated:Connect(fire)
	refreshAmmoDisplay()
end

local function onGunUnequipped()
	if activatedConn then
		activatedConn:Disconnect()
		activatedConn = nil
	end
	equippedGun      = nil
	isReloading      = false
	isOnFireCooldown = false
	ammoLabel.Text   = ""
end

local function watchForGun(char: Model)
	char.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") and child.Name == Config.GUN_NAME then
			onGunEquipped(child :: Tool)
		end
	end)
	char.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Tool") and child.Name == Config.GUN_NAME then
			onGunUnequipped()
		end
	end)
end

function GunManager.init(label: TextLabel, shoot: RemoteEvent)
	ammoLabel  = label
	shootEvent = shoot

	localPlayer.CharacterAdded:Connect(watchForGun)
	if localPlayer.Character then
		watchForGun(localPlayer.Character)
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.R then
			task.spawn(reload)
		end
	end)
end

return GunManager
