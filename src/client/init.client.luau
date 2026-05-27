--!strict

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunManager        = require(script.GunManager)
local CharacterManager  = require(script.CharacterManager)
local LobbyManager      = require(script.LobbyManager)

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

local waveLabel  = buildWaveLabel()
local ammoLabel  = buildAmmoLabel()
waveEvent.OnClientEvent:Connect(function(waveNumber: number)
	waveLabel.Text = "WAVE " .. waveNumber
	task.delay(3, function()
		waveLabel.Text = ""
	end)
end)

CharacterManager.init()
GunManager.init(ammoLabel, shootEvent)
LobbyManager.init(screenGui, requestPlayEvent)

