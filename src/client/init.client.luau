-- Handles laser shooting, sprinting, jumping, and the wave announcement UI.
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

local shootEvent = ReplicatedStorage:WaitForChild("ShootLaser")
local waveEvent  = ReplicatedStorage:WaitForChild("WaveAnnounce")

-- Wave announcement UI
local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Parent = player.PlayerGui

local waveLabel = Instance.new("TextLabel")
waveLabel.Size                   = UDim2.new(0.4, 0, 0.1, 0)
waveLabel.Position               = UDim2.new(0.3, 0, 0.1, 0)
waveLabel.BackgroundTransparency = 1
waveLabel.TextColor3             = Color3.new(1, 0.2, 0.2)
waveLabel.TextScaled             = true
waveLabel.Font                   = Enum.Font.GothamBold
waveLabel.Text                   = ""
waveLabel.Parent                 = screenGui

waveEvent.OnClientEvent:Connect(function(waveNumber)
	waveLabel.Text = "WAVE " .. waveNumber
	task.delay(3, function()
		waveLabel.Text = ""
	end)
end)

-- Character setup
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

humanoid.JumpPower = Config.PLAYER_JUMP_POWER

-- Sprint
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = Config.PLAYER_SPRINT_SPEED
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = Config.PLAYER_WALK_SPEED
	end
end)

-- Laser gun
local fireCooldown = false

mouse.Button1Down:Connect(function()
	if fireCooldown then return end
	fireCooldown = true

	local hitPosition = mouse.Hit.Position

	-- Draw a visible laser beam
	local beam = Instance.new("Part")
	beam.Name       = "LaserBeam"
	beam.BrickColor = BrickColor.new("Bright red")
	beam.Material   = Enum.Material.Neon
	beam.Anchored   = true
	beam.CanCollide = false
	beam.Size       = Vector3.new(0.1, 0.1, (rootPart.Position - hitPosition).Magnitude)
	beam.CFrame     = CFrame.lookAt(rootPart.Position, hitPosition)
	                  * CFrame.new(0, 0, -beam.Size.Z / 2)
	beam.Parent     = workspace

	-- Raycast to find what the laser actually hits
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character}
	raycastParams.FilterType                 = Enum.RaycastFilterType.Exclude

	local rayDirection = (hitPosition - rootPart.Position).Unit * Config.LASER_RANGE
	local result       = workspace:Raycast(rootPart.Position, rayDirection, raycastParams)

	local zombieModel = nil
	if result and result.Instance then
		local hitModel = result.Instance.Parent
		if hitModel and hitModel.Name == "Zombie" then
			zombieModel = hitModel
		end
	end

	-- Ask the server to apply damage (server validates before dealing damage)
	shootEvent:FireServer(zombieModel)

	task.delay(0.1, function()
		beam:Destroy()
	end)

	task.delay(Config.LASER_FIRE_COOLDOWN, function()
		fireCooldown = false
	end)
end)

