--!strict

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local localPlayer = Players.LocalPlayer
local mouse       = localPlayer:GetMouse()

local shootEvent       = ReplicatedStorage:WaitForChild("ShootGun") :: RemoteEvent
local waveEvent        = ReplicatedStorage:WaitForChild("WaveAnnounce") :: RemoteEvent
local requestPlayEvent = ReplicatedStorage:WaitForChild("RequestPlay") :: RemoteEvent

-- ── HUD ───────────────────────────────────────────────────────────────────────

local screenGui        = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Parent       = localPlayer.PlayerGui

local function buildWaveLabel(): TextLabel
	local label                  = Instance.new("TextLabel")
	label.Size                   = UDim2.new(0.4, 0, 0.1, 0)
	label.Position               = UDim2.new(0.3, 0, 0.1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3             = Color3.new(1, 0.2, 0.2)
	label.TextScaled             = true
	label.Font                   = Enum.Font.GothamBold
	label.Text                   = ""
	label.Parent                 = screenGui
	return label
end

local function buildAmmoLabel(): TextLabel
	local label                  = Instance.new("TextLabel")
	label.Size                   = UDim2.new(0.18, 0, 0.07, 0)
	label.Position               = UDim2.new(0.80, 0, 0.88, 0)
	label.BackgroundTransparency = 1
	label.TextColor3             = Color3.new(1, 1, 1)
	label.TextScaled             = true
	label.Font                   = Enum.Font.GothamBold
	label.Text                   = ""
	label.Parent                 = screenGui
	return label
end

local function buildPlayPrompt(): Frame
	local frame                  = Instance.new("Frame")
	frame.Size                   = UDim2.new(0.32, 0, 0.22, 0)
	frame.Position               = UDim2.new(0.34, 0, 0.38, 0)
	frame.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel        = 0
	frame.Visible                = false
	frame.Parent                 = screenGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

	local title                  = Instance.new("TextLabel")
	title.Size                   = UDim2.new(1, 0, 0.42, 0)
	title.Position               = UDim2.new(0, 0, 0.04, 0)
	title.BackgroundTransparency = 1
	title.TextColor3             = Color3.new(1, 1, 1)
	title.TextScaled             = true
	title.Font                   = Enum.Font.GothamBold
	title.Text                   = "ALIEN INVASION"
	title.Parent                 = frame

	local button                 = Instance.new("TextButton")
	button.Size                  = UDim2.new(0.68, 0, 0.36, 0)
	button.Position              = UDim2.new(0.16, 0, 0.54, 0)
	button.BackgroundColor3      = Color3.fromRGB(30, 180, 70)
	button.BorderSizePixel       = 0
	button.TextColor3            = Color3.new(1, 1, 1)
	button.TextScaled            = true
	button.Font                  = Enum.Font.GothamBold
	button.Text                  = "PLAY GAME"
	button.Parent                = frame
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

	button.MouseButton1Click:Connect(function()
		frame.Visible = false
		requestPlayEvent:FireServer()
	end)

	return frame
end

local waveLabel  = buildWaveLabel()
local ammoLabel  = buildAmmoLabel()
local playPrompt = buildPlayPrompt()

-- ── Wave announcements ────────────────────────────────────────────────────────

waveEvent.OnClientEvent:Connect(function(waveNumber: number)
	waveLabel.Text = "WAVE " .. waveNumber
	task.delay(3, function()
		waveLabel.Text = ""
	end)
end)

-- ── Character ─────────────────────────────────────────────────────────────────

local character: Model?   = nil
local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil

local function onCharacterAdded(newCharacter: Model)
	character = newCharacter
	humanoid  = newCharacter:WaitForChild("Humanoid") :: Humanoid
	rootPart  = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	humanoid.JumpPower = Config.PLAYER_JUMP_POWER
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)
if localPlayer.Character then
	onCharacterAdded(localPlayer.Character)
end

-- ── Sprint ────────────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed or not humanoid then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = Config.PLAYER_SPRINT_SPEED
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if not humanoid then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = Config.PLAYER_WALK_SPEED
	end
end)

-- ── Gun system ────────────────────────────────────────────────────────────────

local ammo: number                       = Config.GUN_MAG_SIZE
local isReloading: boolean               = false
local isOnFireCooldown: boolean          = false
local equippedGun: Tool?                 = nil
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
	if isOnFireCooldown or isReloading or not equippedGun or not character or not rootPart then return end
	if ammo <= 0 then
		task.spawn(reload)
		return
	end

	isOnFireCooldown = true
	ammo -= 1
	refreshAmmoDisplay()

	local muzzle  = equippedGun:FindFirstChild("Muzzle", true)
	local origin: Vector3 = (muzzle and muzzle:IsA("BasePart"))
		and (muzzle :: BasePart).WorldPosition
		or  (rootPart :: BasePart).Position

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

-- ── GoToGame pad ──────────────────────────────────────────────────────────────

local function waitForGamePad(): BasePart
	while true do
		local found = workspace:FindFirstChild(Config.LOBBY_PAD_NAME, true)
		if found and found:IsA("BasePart") then
			return found :: BasePart
		end
		task.wait(1)
	end
end

local function watchGamePad()
	local pad        = waitForGamePad()
	local touchCount = 0

	local function isLocalCharacterPart(hit: BasePart): boolean
		return character ~= nil and hit:IsDescendantOf(character :: Model)
	end

	pad.Touched:Connect(function(hit: BasePart)
		if not isLocalCharacterPart(hit) then return end
		touchCount += 1
		playPrompt.Visible = touchCount > 0
	end)

	pad.TouchEnded:Connect(function(hit: BasePart)
		if not isLocalCharacterPart(hit) then return end
		touchCount = math.max(0, touchCount - 1)
		playPrompt.Visible = touchCount > 0
	end)

	localPlayer.CharacterAdded:Connect(function()
		touchCount = 0
		playPrompt.Visible = false
	end)
end

task.spawn(watchGamePad)

