--!strict

local Players           = game:GetService("Players")
local PhysicsService    = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config        = require(ReplicatedStorage.Shared.Config)
local ZombieManager = require(script.Parent.ZombieManager)
local WaveManager   = require(script.Parent.WaveManager)

local function registerCollisionGroups()
	-- ZombiePassthrough parts block players but not zombies; assign in Studio per-part.
	pcall(function() PhysicsService:RegisterCollisionGroup("Zombies") end)
	pcall(function() PhysicsService:RegisterCollisionGroup("ZombiePassthrough") end)
	PhysicsService:CollisionGroupSetCollidable("Zombies", "ZombiePassthrough", false)
end

local function createRemoteEvent(name: string): RemoteEvent
	local event  = Instance.new("RemoteEvent")
	event.Name   = name
	event.Parent = ReplicatedStorage
	return event
end

local function spawnAtLobby(character: Model)
	local lobby = workspace:FindFirstChild(Config.LOBBY_NAME)
	if not lobby or not lobby:IsA("Model") then return end
	local spawnPart = lobby:FindFirstChild("Spawn_In", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		character:PivotTo((spawnPart :: BasePart).CFrame * CFrame.new(0, 5, 0))
	else
		character:PivotTo((lobby :: Model):GetPivot() * CFrame.new(0, 5, 0))
	end
end

registerCollisionGroups()

local shootEvent       = createRemoteEvent("ShootGun")
local waveEvent        = createRemoteEvent("WaveAnnounce")
local waveClearEvent   = createRemoteEvent("WaveClear")
local requestPlayEvent = createRemoteEvent("RequestPlay")

local activePlayers: { [Player]: boolean } = {}

local function isEligibleToPlay(player: Player): boolean
	if activePlayers[player] then return false end
	local character = player.Character
	local humanoid  = character and character:FindFirstChildWhichIsA("Humanoid")
	return humanoid ~= nil and (humanoid :: Humanoid).Health > 0
end

shootEvent.OnServerEvent:Connect(function(_player: Player, zombieModel: Instance)
	ZombieManager.damageZombie(zombieModel :: Model?, Config.GUN_DAMAGE)
end)

requestPlayEvent.OnServerEvent:Connect(function(player: Player)
	if not isEligibleToPlay(player) then return end
	activePlayers[player] = true
	task.spawn(function()
		WaveManager.startBattle(player, waveEvent, waveClearEvent)
		activePlayers[player] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	activePlayers[player] = nil
end)

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(spawnAtLobby)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
