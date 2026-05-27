-- Entry point: creates shared RemoteEvents and starts the game per player.
local Players           = game:GetService("Players")
local PhysicsService    = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config        = require(ReplicatedStorage.Shared.Config)
local ZombieManager = require(script.Parent.ZombieManager)
local WaveManager   = require(script.Parent.WaveManager)

-- Collision groups:
--   "Zombies"          → assigned to all zombie parts (see ZombieManager)
--   "ZombiePassthrough"→ assign this in Studio to any part zombies should walk through
--   Zombies ↔ ZombiePassthrough = false  (zombies phase through those parts)
--   Everything else (floors, walls, players) collides with zombies normally.
pcall(function() PhysicsService:RegisterCollisionGroup("Zombies") end)
pcall(function() PhysicsService:RegisterCollisionGroup("ZombiePassthrough") end)
PhysicsService:CollisionGroupSetCollidable("Zombies", "ZombiePassthrough", false)

-- RemoteEvents live in ReplicatedStorage so the client can reach them
local shootEvent = Instance.new("RemoteEvent")
shootEvent.Name   = "ShootGun"
shootEvent.Parent = ReplicatedStorage

local waveEvent = Instance.new("RemoteEvent")
waveEvent.Name   = "WaveAnnounce"
waveEvent.Parent = ReplicatedStorage

local requestPlayEvent = Instance.new("RemoteEvent")
requestPlayEvent.Name   = "RequestPlay"
requestPlayEvent.Parent = ReplicatedStorage

-- Server validates and applies gun damage reported by the client
shootEvent.OnServerEvent:Connect(function(player, zombieModel)
	ZombieManager.damageZombie(zombieModel, Config.GUN_DAMAGE)
end)

-- Starts the battle when the player steps on the GoToGame pad and confirms
local activePlayers = {}
requestPlayEvent.OnServerEvent:Connect(function(player)
	if activePlayers[player] then return end  -- already in a battle
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	activePlayers[player] = true
	task.spawn(function()
		WaveManager.startBattle(player, waveEvent)
		activePlayers[player] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	activePlayers[player] = nil
end)

-- Start the wave loop each time a player's character loads
local function onPlayerAdded(player)
	print("[Server] Initializing game for player: " .. player.Name)
	
	-- Spawn character at Lobby center on load (no auto-start; player uses the pad)
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
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
