-- Handles gun shooting, sprinting, jumping, and the HUD.
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

local shootEvent       = ReplicatedStorage:WaitForChild("ShootGun")
local waveEvent        = ReplicatedStorage:WaitForChild("WaveAnnounce")
local requestPlayEvent = ReplicatedStorage:WaitForChild("RequestPlay")

-- HUD -----------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Parent = player.PlayerGui

-- Wave announcement
local waveLabel = Instance.new("TextLabel")
waveLabel.Size                   = UDim2.new(0.4, 0, 0.1, 0)
waveLabel.Position               = UDim2.new(0.3, 0, 0.1, 0)
waveLabel.BackgroundTransparency = 1
waveLabel.TextColor3             = Color3.new(1, 0.2, 0.2)
waveLabel.TextScaled             = true
waveLabel.Font                   = Enum.Font.GothamBold
waveLabel.Text                   = ""
waveLabel.Parent                 = screenGui

-- Ammo counter (bottom-right)
local ammoLabel = Instance.new("TextLabel")
ammoLabel.Size                   = UDim2.new(0.18, 0, 0.07, 0)
ammoLabel.Position               = UDim2.new(0.80, 0, 0.88, 0)
ammoLabel.BackgroundTransparency = 1
ammoLabel.TextColor3             = Color3.new(1, 1, 1)
ammoLabel.TextScaled             = true
ammoLabel.Font                   = Enum.Font.GothamBold
ammoLabel.Text                   = ""
ammoLabel.Parent                 = screenGui

-- Play Game prompt (shown when standing on GoToGame pad) --------------------
local playFrame = Instance.new("Frame")
playFrame.Size                   = UDim2.new(0.32, 0, 0.22, 0)
playFrame.Position               = UDim2.new(0.34, 0, 0.38, 0)
playFrame.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
playFrame.BackgroundTransparency = 0.25
playFrame.BorderSizePixel        = 0
playFrame.Visible                = false
playFrame.Parent                 = screenGui
Instance.new("UICorner", playFrame).CornerRadius = UDim.new(0, 14)

local playTitle = Instance.new("TextLabel")
playTitle.Size                   = UDim2.new(1, 0, 0.42, 0)
playTitle.Position               = UDim2.new(0, 0, 0.04, 0)
playTitle.BackgroundTransparency = 1
playTitle.TextColor3             = Color3.new(1, 1, 1)
playTitle.TextScaled             = true
playTitle.Font                   = Enum.Font.GothamBold
playTitle.Text                   = "ALIEN INVASION"
playTitle.Parent                 = playFrame

local playButton = Instance.new("TextButton")
playButton.Size                  = UDim2.new(0.68, 0, 0.36, 0)
playButton.Position              = UDim2.new(0.16, 0, 0.54, 0)
playButton.BackgroundColor3      = Color3.fromRGB(30, 180, 70)
playButton.BorderSizePixel       = 0
playButton.TextColor3            = Color3.new(1, 1, 1)
playButton.TextScaled            = true
playButton.Font                  = Enum.Font.GothamBold
playButton.Text                  = "PLAY GAME"
playButton.Parent                = playFrame
Instance.new("UICorner", playButton).CornerRadius = UDim.new(0, 8)

playButton.MouseButton1Click:Connect(function()
	playFrame.Visible = false
	requestPlayEvent:FireServer()
end)

waveEvent.OnClientEvent:Connect(function(waveNumber)
	waveLabel.Text = "WAVE " .. waveNumber
	task.delay(3, function()
		waveLabel.Text = ""
	end)
end)

-- Character setup -----------------------------------------------------------
local character, humanoid, rootPart

local function onCharacterAdded(newChar)
	character = newChar
	humanoid  = character:WaitForChild("Humanoid")
	rootPart  = character:WaitForChild("HumanoidRootPart")

	humanoid.JumpPower = Config.PLAYER_JUMP_POWER
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

-- Sprint --------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not humanoid then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = Config.PLAYER_SPRINT_SPEED
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not humanoid then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = Config.PLAYER_WALK_SPEED
	end
end)

-- Gun system ----------------------------------------------------------------
local ammo          = Config.GUN_MAG_SIZE
local reloading     = false
local fireCooldown  = false
local equippedGun   = nil
local activatedConn = nil

local function updateAmmoUI()
	if not equippedGun then
		ammoLabel.Text = ""
		return
	end
	if reloading then
		ammoLabel.Text       = "RELOADING..."
		ammoLabel.TextColor3 = Color3.new(1, 0.6, 0)
	else
		ammoLabel.Text       = ammo .. " / " .. Config.GUN_MAG_SIZE
		ammoLabel.TextColor3 = ammo > 0 and Color3.new(1, 1, 1) or Color3.new(1, 0.2, 0.2)
	end
end

local function reload()
	if reloading or not equippedGun or ammo == Config.GUN_MAG_SIZE then return end
	reloading = true
	updateAmmoUI()
	task.wait(Config.GUN_RELOAD_TIME)
	if equippedGun then  -- still holding the gun after the wait
		ammo = Config.GUN_MAG_SIZE
	end
	reloading = false
	updateAmmoUI()
end

local function fire()
	if fireCooldown or reloading or not equippedGun or not character then return end
	if ammo <= 0 then
		task.spawn(reload)
		return
	end

	fireCooldown = true
	ammo -= 1
	updateAmmoUI()

	-- Muzzle flash
	local muzzle = equippedGun:FindFirstChild("Muzzle", true)
	local origin  = muzzle and muzzle.WorldPosition or rootPart.Position

	if muzzle then
		local flash = muzzle:FindFirstChild("FlashLight")
		if flash then
			flash.Enabled = true
			task.delay(Config.GUN_MUZZLE_DELAY, function() flash.Enabled = false end)
		end
		local particle = muzzle:FindFirstChildWhichIsA("ParticleEmitter")
		if particle then particle:Emit(8) end
	end

	-- Raycast from muzzle toward the mouse cursor
	local direction = (mouse.Hit.Position - origin).Unit * Config.GUN_RANGE
	local params    = RaycastParams.new()
	params.FilterDescendantsInstances = {character}
	params.FilterType                 = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, direction, params)

	local hitZombie = nil
	if result and result.Instance then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and model.Name == "Zombie" then
			hitZombie = model
		end
	end
	shootEvent:FireServer(hitZombie)

	task.wait(Config.GUN_FIRE_COOLDOWN)
	fireCooldown = false
end

local function onGunEquipped(tool)
	equippedGun  = tool
	ammo         = Config.GUN_MAG_SIZE
	reloading    = false
	fireCooldown = false
	updateAmmoUI()
	activatedConn = tool.Activated:Connect(fire)
end

local function onGunUnequipped()
	if activatedConn then
		activatedConn:Disconnect()
		activatedConn = nil
	end
	equippedGun  = nil
	reloading    = false
	fireCooldown = false
	ammoLabel.Text = ""
end

local function watchCharacterForGun(char)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == Config.GUN_NAME then
			onGunEquipped(child)
		end
	end)
	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child.Name == Config.GUN_NAME then
			onGunUnequipped()
		end
	end)
end

player.CharacterAdded:Connect(watchCharacterForGun)
if player.Character then
	watchCharacterForGun(player.Character)
end

-- Reload on R
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.R then
		task.spawn(reload)
	end
end)

-- GoToGame pad: show play prompt when standing on it ----------------------
task.spawn(function()
	-- Wait for the pad to exist (it's inside the lobby model)
	local pad
	repeat
		task.wait(1)
		pad = workspace:FindFirstChild(Config.LOBBY_PAD_NAME, true)
	until pad

	local touchCount = 0

	pad.Touched:Connect(function(hit)
		if not character then return end
		if not hit:IsDescendantOf(character) then return end
		touchCount += 1
		if touchCount == 1 then
			playFrame.Visible = true
		end
	end)

	pad.TouchEnded:Connect(function(hit)
		if not character then return end
		if not hit:IsDescendantOf(character) then return end
		touchCount = math.max(0, touchCount - 1)
		if touchCount == 0 then
			playFrame.Visible = false
		end
	end)

	-- Reset when the character respawns (e.g. after dying)
	player.CharacterAdded:Connect(function()
		touchCount = 0
		playFrame.Visible = false
	end)
end)

