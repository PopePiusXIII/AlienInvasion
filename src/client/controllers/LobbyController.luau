--!strict
--------------------------------------------------------------------------------
-- LobbyController.luau  (src/client/controllers)
-- Manages the proximity-based GoToGame pad detection and the Play prompt UI.
-- Single Responsibility: lobby interaction only.
-- Fires RequestPlay via Logger.fireServer (net trace enabled).
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework     = require(ReplicatedStorage.Shared.Framework)
local Logger        = require(ReplicatedStorage.Shared.Logger)
local Config        = require(ReplicatedStorage.Shared.Config)
local RemoteNames   = require(ReplicatedStorage.Shared.RemoteNames)
local HudController = require(script.Parent.HudController)

local TAG = "LobbyController"

local LobbyController = Framework.CreateController({ Name = TAG })

local _localPlayer  = Players.LocalPlayer
local _character:   Model?  = nil
local _requestPlayRemote: RemoteEvent

-- ── UI builder ────────────────────────────────────────────────────────────────

local function buildPlayPrompt(parent: ScreenGui): Frame
	local frame                  = Instance.new("Frame")
	frame.Name                   = "PlayPrompt"
	frame.Size                   = UDim2.new(0.32, 0, 0.22, 0)
	frame.Position               = UDim2.new(0.34, 0, 0.38, 0)
	frame.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel        = 0
	frame.Visible                = false
	frame.Parent                 = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

	local title                  = Instance.new("TextLabel")
	title.Name                   = "Title"
	title.Size                   = UDim2.new(1, 0, 0.42, 0)
	title.Position               = UDim2.new(0, 0, 0.04, 0)
	title.BackgroundTransparency = 1
	title.TextColor3             = Color3.new(1, 1, 1)
	title.TextScaled             = true
	title.Font                   = Enum.Font.GothamBold
	title.Text                   = "ALIEN INVASION"
	title.Parent                 = frame

	local button                 = Instance.new("TextButton")
	button.Name                  = "PlayButton"
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

	return frame
end

-- ── Private helpers ───────────────────────────────────────────────────────────

local function waitForGamePad(): BasePart
	-- Poll until the pad exists; retries handle delayed map loading.
	while true do
		local found = workspace:FindFirstChild(Config.LOBBY_PAD_NAME, true)
		if found and found:IsA("BasePart") then
			return found :: BasePart
		end
		task.wait(1)
	end
end

local function startProximityWatcher(playPrompt: Frame)
	local pad       = waitForGamePad()
	local THRESHOLD = 12    -- studs; show prompt when within this range
	local playing   = false -- true once the player commits; hides prompt

	-- Reset the playing flag on respawn so the prompt re-appears next session.
	_localPlayer.CharacterAdded:Connect(function()
		playing = false
	end)

	local button = playPrompt:FindFirstChild("PlayButton") :: TextButton?
	if button then
		button.MouseButton1Click:Connect(function()
			playing = true
			-- Logger.fireServer emits a net trace when DEBUG_NETWORKING = true.
			Logger.fireServer(_requestPlayRemote)
			Logger.info(TAG, "RequestPlay fired.")
		end)
	end

	-- Drive visibility from proximity each frame — deterministic, no missed events.
	RunService.Heartbeat:Connect(function()
		if playing then
			playPrompt.Visible = false
			return
		end
		local char = _character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- Guard destroyed parts: Position == math.huge when a part is unparented.
		playPrompt.Visible = root ~= nil
			and (root :: BasePart).Position.X ~= math.huge
			and ((root :: BasePart).Position - pad.Position).Magnitude <= THRESHOLD
	end)
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function LobbyController:Init()
	_localPlayer.CharacterAdded:Connect(function(newCharacter: Model)
		_character = newCharacter
	end)
	if _localPlayer.Character then
		_character = _localPlayer.Character
	end

	Logger.info(TAG, "Initialized.")
end

function LobbyController:Start()
	_requestPlayRemote = Framework.GetRemote(RemoteNames.REQUEST_PLAY)

	-- Parent the prompt into the shared ScreenGui owned by HudController.
	local playPrompt = buildPlayPrompt(HudController.getScreenGui())

	-- Run the proximity watcher in a separate thread (waitForGamePad may yield).
	task.spawn(startProximityWatcher, playPrompt)

	Logger.info(TAG, "RequestPlay remote acquired; proximity watcher started.")
end

return LobbyController
