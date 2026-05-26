-- Handles laser shooting, sprinting, jumping, and the wave announcement UI.
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

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

-- Sprint
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

-- Laser gun
local fireCooldown = false

mouse.Button1Down:Connect(function()
	if fireCooldown or not rootPart or not character then return end
	fireCooldown = true

	local origin    = rootPart.Position
	local direction = (mouse.Hit.Position - origin).Unit * Config.LASER_RANGE

	-- Raycast first so the beam draws to the actual impact point
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character}
	raycastParams.FilterType                 = Enum.RaycastFilterType.Exclude

	local result   = workspace:Raycast(origin, direction, raycastParams)
	local endpoint = result and result.Position or (origin + direction)

	-- Draw beam from gun barrel to impact point
	local beamLength = (endpoint - origin).Magnitude
	local beam = Instance.new("Part")
	beam.Name        = "LaserBeam"
	beam.BrickColor  = BrickColor.new("Bright red")
	beam.Material    = Enum.Material.Neon
	beam.Anchored    = true
	beam.CanCollide  = false
	beam.CastShadow  = false
	beam.Size        = Vector3.new(0.1, 0.1, beamLength)
	beam.CFrame      = CFrame.lookAt(origin, endpoint) * CFrame.new(0, 0, -beamLength / 2)
	beam.Parent      = workspace
	Debris:AddItem(beam, 0.1)

	-- Tell the server which zombie was hit (server re-validates before applying damage)
	local zombieModel = nil
	if result and result.Instance then
		local hitModel = result.Instance.Parent
		if hitModel and hitModel.Name == "Zombie" then
			zombieModel = hitModel
		end
	end
	shootEvent:FireServer(zombieModel)

	task.delay(Config.LASER_FIRE_COOLDOWN, function()
		fireCooldown = false
	end)
end)

