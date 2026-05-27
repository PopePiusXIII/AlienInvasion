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
		frame.Visible = false
		requestPlayEvent:FireServer()
	end)

	return frame
end

local function watchGamePad(playPrompt: Frame)
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
