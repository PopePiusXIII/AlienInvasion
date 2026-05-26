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
local function onPlayerAdded(player)
	print("[Server] Initializing game for player: " .. player.Name)
	
	player.CharacterAdded:Connect(function(character)
		-- Spawn character at Lobby center immediately on load
		local lobby = workspace:FindFirstChild(Config.LOBBY_NAME)
		if lobby then
			local lobbyCenter = lobby:FindFirstChild("Spawn_In", true)
			if lobbyCenter and lobbyCenter:IsA("BasePart") then
				character:PivotTo(lobbyCenter.CFrame * CFrame.new(0, 5, 0))
			else
				character:PivotTo(lobby:GetPivot() * CFrame.new(0, 5, 0))
			end
			print("[Server] Teleported " .. player.Name .. " to Lobby center (Spawn_In)")
		end
	end)
	
	-- Start the single persistent wave loop for this player
	task.spawn(function()
		WaveManager.startForPlayer(player, waveEvent)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
