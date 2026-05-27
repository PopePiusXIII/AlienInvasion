--!strict
-- LobbyClient.client.luau  (Lobby Place — StarterPlayerScripts)
-- Shows the Find Match / Cancel queue UI and handles the MatchFound countdown.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local joinQueueEvent  = ReplicatedStorage:WaitForChild("JoinQueue")  :: RemoteEvent
local leaveQueueEvent = ReplicatedStorage:WaitForChild("LeaveQueue") :: RemoteEvent
local matchFoundEvent = ReplicatedStorage:WaitForChild("MatchFound") :: RemoteEvent

-- ── UI construction ───────────────────────────────────────────────────────────

local screenGui             = Instance.new("ScreenGui")
screenGui.ResetOnSpawn      = false
screenGui.IgnoreGuiInset    = true
screenGui.Parent            = player.PlayerGui

-- Centred panel
local frame                      = Instance.new("Frame")
frame.Size                       = UDim2.new(0.34, 0, 0.28, 0)
frame.Position                   = UDim2.new(0.33, 0, 0.36, 0)
frame.BackgroundColor3           = Color3.fromRGB(12, 12, 22)
frame.BackgroundTransparency     = 0.15
frame.BorderSizePixel            = 0
frame.Parent                     = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 18)

-- Accent bar at top
local accent                 = Instance.new("Frame")
accent.Size                  = UDim2.new(1, 0, 0.07, 0)
accent.Position              = UDim2.new(0, 0, 0, 0)
accent.BackgroundColor3      = Color3.fromRGB(220, 60, 60)
accent.BorderSizePixel       = 0
accent.Parent                = frame
Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 18)

-- Title
local titleLabel                    = Instance.new("TextLabel")
titleLabel.Size                     = UDim2.new(1, 0, 0.28, 0)
titleLabel.Position                 = UDim2.new(0, 0, 0.08, 0)
titleLabel.BackgroundTransparency   = 1
titleLabel.TextColor3               = Color3.new(1, 1, 1)
titleLabel.TextScaled               = true
titleLabel.Font                     = Enum.Font.GothamBold
titleLabel.Text                     = "ALIEN INVASION"
titleLabel.Parent                   = frame

-- Status / countdown label
local statusLabel                   = Instance.new("TextLabel")
statusLabel.Size                    = UDim2.new(0.88, 0, 0.2, 0)
statusLabel.Position                = UDim2.new(0.06, 0, 0.38, 0)
statusLabel.BackgroundTransparency  = 1
statusLabel.TextColor3              = Color3.fromRGB(195, 195, 195)
statusLabel.TextScaled              = true
statusLabel.Font                    = Enum.Font.Gotham
statusLabel.Text                    = "Click FIND MATCH to enter the queue."
statusLabel.Parent                  = frame

-- Find Match / Cancel button
local matchButton                   = Instance.new("TextButton")
matchButton.Size                    = UDim2.new(0.58, 0, 0.24, 0)
matchButton.Position                = UDim2.new(0.21, 0, 0.66, 0)
matchButton.BackgroundColor3        = Color3.fromRGB(30, 155, 70)
matchButton.BorderSizePixel         = 0
matchButton.TextColor3              = Color3.new(1, 1, 1)
matchButton.TextScaled              = true
matchButton.Font                    = Enum.Font.GothamBold
matchButton.Text                    = "FIND MATCH"
matchButton.Parent                  = frame
Instance.new("UICorner", matchButton).CornerRadius = UDim.new(0, 10)

-- ── State ────────────────────────────────────────────────────────────────────

local isQueued    = false
local matchLocked = false  -- true once a match is found; prevents further input

local function setQueued(queued: boolean)
	isQueued = queued
	if queued then
		matchButton.Text             = "CANCEL"
		matchButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
		statusLabel.Text             = "Searching for players..."
	else
		matchButton.Text             = "FIND MATCH"
		matchButton.BackgroundColor3 = Color3.fromRGB(30, 155, 70)
		statusLabel.Text             = "Click FIND MATCH to enter the queue."
	end
end

-- ── Button handler ────────────────────────────────────────────────────────────

matchButton.MouseButton1Click:Connect(function()
	if matchLocked then return end
	if isQueued then
		leaveQueueEvent:FireServer()
		setQueued(false)
	else
		joinQueueEvent:FireServer()
		setQueued(true)
	end
end)

-- ── Match found ───────────────────────────────────────────────────────────────

matchFoundEvent.OnClientEvent:Connect(function()
	matchLocked       = true
	matchButton.Visible = false

	-- 3-second countdown, then "Teleporting…"
	for i = 3, 1, -1 do
		statusLabel.Text = string.format("Match found!  Starting in  %d…", i)
		statusLabel.TextColor3 = Color3.fromRGB(80, 220, 100)
		task.wait(1)
	end
	statusLabel.Text = "Teleporting…"
end)
