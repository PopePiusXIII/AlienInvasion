--!strict

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIAnimator      = game:GetService("TweenService")

local Config            = require(ReplicatedStorage.Shared.Config)
local GunManager        = require(script.GunManager)
local CharacterManager  = require(script.CharacterManager)
local LobbyManager      = require(script.LobbyManager)

local localPlayer = Players.LocalPlayer

local shootEvent       = ReplicatedStorage:WaitForChild("ShootGun") :: RemoteEvent
local waveEvent        = ReplicatedStorage:WaitForChild("WaveAnnounce") :: RemoteEvent
local waveClearEvent   = ReplicatedStorage:WaitForChild("WaveClear") :: RemoteEvent
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

local waveLabel  = buildWaveLabel()
local ammoLabel  = buildAmmoLabel()

local function showUpgradeEcho(text: string)
	local label                  = Instance.new("TextLabel")
	label.Size                   = UDim2.new(0.4, 0, 0.08, 0)
	label.Position               = UDim2.new(0.3, 0, 0.42, 0)
	label.BackgroundTransparency = 1
	label.TextColor3             = Color3.fromRGB(255, 210, 50)
	label.TextStrokeTransparency = 0.4
	label.TextScaled             = true
	label.Font                   = Enum.Font.GothamBold
	label.Text                   = text
	label.Parent                 = screenGui

	local fadeOut = UIAnimator:Create(label, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position         = UDim2.new(0.3, 0, 0.28, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		label:Destroy()
	end)
end

waveEvent.OnClientEvent:Connect(function(waveNumber: number)
	waveLabel.Text = "WAVE " .. waveNumber
	task.delay(3, function()
		waveLabel.Text = ""
	end)
end)

waveClearEvent.OnClientEvent:Connect(function()
	CharacterManager.boostStat("walkSpeed",   Config.WAVE_CLEAR_SPEED_BOOST)
	CharacterManager.boostStat("sprintSpeed", Config.WAVE_CLEAR_SPEED_BOOST)
	CharacterManager.boostStat("scale",       Config.WAVE_CLEAR_SCALE_BOOST)
	local stats = CharacterManager.getStats()
	print(string.format("[Client] Stats upgraded — WalkSpeed: %.0f  SprintSpeed: %.0f  Scale: %.2f",
		stats.walkSpeed, stats.sprintSpeed, stats.scale))
	showUpgradeEcho(string.format("+%d SPD  •  +%d%% SIZE",
		Config.WAVE_CLEAR_SPEED_BOOST,
		math.round(Config.WAVE_CLEAR_SCALE_BOOST * 100)))
end)

CharacterManager.init()
GunManager.init(ammoLabel, shootEvent)
LobbyManager.init(screenGui, requestPlayEvent)

