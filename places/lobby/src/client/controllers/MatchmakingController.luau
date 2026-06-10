--!strict
--------------------------------------------------------------------------------
-- MatchmakingController.luau  (places/lobby/src/client/controllers)
-- Owns all Lobby UI: Find Match / Cancel panel and Match Found countdown.
-- Listens to MatchFound; fires JoinQueue / LeaveQueue via Logger.fireServer.
-- Single Responsibility: lobby matchmaking UI and client-side queue state.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Framework   = require(ReplicatedStorage.Shared.Framework)
local Logger      = require(ReplicatedStorage.Shared.Logger)
local Config      = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local TAG = "MatchmakingController"

local MatchmakingController = Framework.CreateController({ Name = TAG })

local _localPlayer     = Players.LocalPlayer
local _joinQueueRemote:  RemoteEvent
local _leaveQueueRemote: RemoteEvent
local _matchFoundRemote: RemoteEvent

-- UI references, populated during Init.
local _panel:        Frame
local _statusLabel:  TextLabel
local _matchButton:  TextButton

-- Client-side queue state.
local _isQueued    = false
local _matchLocked = false  -- true once a match is found; prevents further input

-- ── UI builder ────────────────────────────────────────────────────────────────

local function buildLobbyUi(): (Frame, TextLabel, TextButton)
	local screenGui             = Instance.new("ScreenGui")
	screenGui.Name              = "LobbyMatchmakingGui"
	screenGui.ResetOnSpawn      = false
	screenGui.IgnoreGuiInset    = true
	screenGui.Parent            = _localPlayer.PlayerGui

	-- Centred panel (hidden until player is near the GoToGame pad)
	local frame                      = Instance.new("Frame")
	frame.Name                       = "Panel"
	frame.Size                       = UDim2.new(0.34, 0, 0.28, 0)
	frame.Position                   = UDim2.new(0.33, 0, 0.36, 0)
	frame.BackgroundColor3           = Color3.fromRGB(12, 12, 22)
	frame.BackgroundTransparency     = 0.15
	frame.BorderSizePixel            = 0
	frame.Visible                    = false
	frame.Parent                     = screenGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 18)

	-- Red accent bar at top
	local accent                 = Instance.new("Frame")
	accent.Name                  = "Accent"
	accent.Size                  = UDim2.new(1, 0, 0.07, 0)
	accent.BackgroundColor3      = Color3.fromRGB(220, 60, 60)
	accent.BorderSizePixel       = 0
	accent.Parent                = frame
	Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 18)

	local titleLabel                    = Instance.new("TextLabel")
	titleLabel.Name                     = "Title"
	titleLabel.Size                     = UDim2.new(1, 0, 0.28, 0)
	titleLabel.Position                 = UDim2.new(0, 0, 0.08, 0)
	titleLabel.BackgroundTransparency   = 1
	titleLabel.TextColor3               = Color3.new(1, 1, 1)
	titleLabel.TextScaled               = true
	titleLabel.Font                     = Enum.Font.GothamBold
	titleLabel.Text                     = "ALIEN INVASION"
	titleLabel.Parent                   = frame

	local statusLabel                   = Instance.new("TextLabel")
	statusLabel.Name                    = "Status"
	statusLabel.Size                    = UDim2.new(0.88, 0, 0.2, 0)
	statusLabel.Position                = UDim2.new(0.06, 0, 0.38, 0)
	statusLabel.BackgroundTransparency  = 1
	statusLabel.TextColor3              = Color3.fromRGB(195, 195, 195)
	statusLabel.TextScaled              = true
	statusLabel.Font                    = Enum.Font.Gotham
	statusLabel.Text                    = "Click FIND MATCH to enter the queue."
	statusLabel.Parent                  = frame

	local matchButton                   = Instance.new("TextButton")
	matchButton.Name                    = "MatchButton"
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

	return frame, statusLabel, matchButton
end

-- ── Private state helpers ─────────────────────────────────────────────────────

local function setQueued(queued: boolean)
	_isQueued = queued
	if queued then
		_matchButton.Text             = "CANCEL"
		_matchButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
		_statusLabel.Text             = "Searching for players..."
	else
		_matchButton.Text             = "FIND MATCH"
		_matchButton.BackgroundColor3 = Color3.fromRGB(30, 155, 70)
		_statusLabel.Text             = "Click FIND MATCH to enter the queue."
	end
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function MatchmakingController:Init()
	_panel, _statusLabel, _matchButton = buildLobbyUi()
	Logger.info(TAG, "Lobby UI created.")
end

function MatchmakingController:Start()
	_joinQueueRemote  = Framework.GetRemote(RemoteNames.JOIN_QUEUE)
	_leaveQueueRemote = Framework.GetRemote(RemoteNames.LEAVE_QUEUE)
	_matchFoundRemote = Framework.GetRemote(RemoteNames.MATCH_FOUND)

	_matchButton.MouseButton1Click:Connect(function()
		if _matchLocked then return end
		if _isQueued then
			Logger.fireServer(_leaveQueueRemote)
			setQueued(false)
		else
			Logger.fireServer(_joinQueueRemote)
			setQueued(true)
		end
	end)

	Logger.wrapClientEvent(_matchFoundRemote, TAG, function()
		_matchLocked        = true
		_matchButton.Visible = false

		-- 3-second countdown, then "Teleporting…" — mirrors the server's task.delay(3).
		for i = 3, 1, -1 do
			_statusLabel.Text      = string.format("Match found!  Starting in  %d…", i)
			_statusLabel.TextColor3 = Color3.fromRGB(80, 220, 100)
			task.wait(1)
		end
		_statusLabel.Text = "Teleporting…"
	end)

	-- Proximity gate: show the panel only when the player is near the GoToGame pad.
	task.spawn(function()
		local pad: BasePart? = nil
		while not pad do
			local found = workspace:FindFirstChild(Config.LOBBY_PAD_NAME, true)
			if found and found:IsA("BasePart") then
				pad = found :: BasePart
			else
				task.wait(1)
			end
		end
		local PAD_THRESHOLD = 12
		RunService.Heartbeat:Connect(function()
			if _matchLocked then return end  -- keep visible during the countdown
			local char = _localPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				_panel.Visible = false
				return
			end
			local inRange = (root.Position - (pad :: BasePart).Position).Magnitude <= PAD_THRESHOLD
			if inRange then
				_panel.Visible = true
			elseif not _isQueued then
				-- Not near pad and not queued → hide.
				_panel.Visible = false
			end
		end)
	end)

	Logger.info(TAG, "Queue remotes acquired; button and MatchFound listener active.")
end

return MatchmakingController
