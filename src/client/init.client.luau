--!strict

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config     = require(ReplicatedStorage.Shared.Config)
local GunManager = require(script.GunManager)

local localPlayer = Players.LocalPlayer

local shootEvent       = ReplicatedStorage:WaitForChild("ShootGun") :: RemoteEvent
local waveEvent        = ReplicatedStorage:WaitForChild("WaveAnnounce") :: RemoteEvent
local requestPlayEvent = ReplicatedStorage:WaitForChild("RequestPlay") :: RemoteEvent

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

waveEvent.OnClientEvent:Connect(function(waveNumber: number)
	waveLabel.Text = "WAVE " .. waveNumber
	task.delay(3, function()
		waveLabel.Text = ""
	end)
end)

local character: Model?   = nil
local humanoid: Humanoid? = nil

local function onCharacterAdded(newCharacter: Model)
	character = newCharacter
	humanoid  = newCharacter:WaitForChild("Humanoid") :: Humanoid
	humanoid.JumpPower = Config.PLAYER_JUMP_POWER
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)
if localPlayer.Character then
	onCharacterAdded(localPlayer.Character)
end

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

GunManager.init(ammoLabel, shootEvent)

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

