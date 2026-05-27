--!strict

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local localPlayer = Players.LocalPlayer

local LobbyManager = {}

local character: Model? = nil

local function waitForGamePad(): BasePart
	while true do
		local found = workspace:FindFirstChild(Config.LOBBY_PAD_NAME, true)
		if found and found:IsA("BasePart") then
			return found :: BasePart
		end
		task.wait(1)
	end
end

local function buildPlayPrompt(screenGui: ScreenGui, requestPlayEvent: RemoteEvent): Frame
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
		requestPlayEvent:FireServer()
	end)

	return frame
end

local function watchGamePad(playPrompt: Frame)
	local RunService = game:GetService("RunService")
	local pad        = waitForGamePad()
	local THRESHOLD  = 12  -- studs from pad centre to show the prompt
	local playing    = false

	-- Suppress prompt while a game is in progress; reset on respawn
	localPlayer.CharacterAdded:Connect(function()
		playing = false
	end)

	-- Set the flag when the player commits to playing
	local button = playPrompt:FindFirstChildWhichIsA("TextButton")
	if button then
		button.MouseButton1Click:Connect(function()
			playing = true
		end)
	end

	-- Drive visibility purely from proximity every frame
	RunService.Heartbeat:Connect(function()
		if playing then
			playPrompt.Visible = false
			return
		end
		local char = character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		playPrompt.Visible = root ~= nil
			and (root :: BasePart).Position.X ~= math.huge  -- guard destroyed parts
			and ((root :: BasePart).Position - pad.Position).Magnitude <= THRESHOLD
	end)
end

function LobbyManager.init(screenGui: ScreenGui, requestPlayEvent: RemoteEvent)
	localPlayer.CharacterAdded:Connect(function(newCharacter: Model)
		character = newCharacter
	end)
	if localPlayer.Character then
		character = localPlayer.Character
	end

	local playPrompt = buildPlayPrompt(screenGui, requestPlayEvent)
	task.spawn(watchGamePad, playPrompt)
end

return LobbyManager
