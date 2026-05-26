-- Entry point: creates shared RemoteEvents and starts the game per player.
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config        = require(ReplicatedStorage.Shared.Config)
local ZombieManager = require(script.Parent.ZombieManager)
local WaveManager   = require(script.Parent.WaveManager)

-- RemoteEvents live in ReplicatedStorage so the client can reach them
local shootEvent = Instance.new("RemoteEvent")
shootEvent.Name   = "ShootLaser"
shootEvent.Parent = ReplicatedStorage

local waveEvent = Instance.new("RemoteEvent")
waveEvent.Name   = "WaveAnnounce"
waveEvent.Parent = ReplicatedStorage

-- Server validates and applies laser damage reported by the client
shootEvent.OnServerEvent:Connect(function(player, zombieModel)
	ZombieManager.damageZombie(zombieModel, Config.LASER_DAMAGE)
end)

-- Start the wave loop each time a player's character loads
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(Config.WAVE_START_DELAY)
		task.spawn(function()
			WaveManager.startForPlayer(player, waveEvent)
		end)
	end)
end)
