--!strict

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config        = require(ReplicatedStorage.Shared.Config)
local ZombieManager = require(script.Parent.ZombieManager)

local WaveManager = {}

local nextMapSlot: number = 0

local function getBattleHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
end

local function findZombieSpawnPosition(map: Model): Vector3
	local spawnPart = map:FindFirstChild("Spawn_Mob", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		return (spawnPart :: BasePart).Position
	end
	return map:GetPivot().Position
end

local function cloneMap(player: Player): Model?
	local template = ServerStorage:FindFirstChild(Config.MAP_NAME)
	if not template or not template:IsA("Model") then
		warn("[WaveManager] Map template not found: " .. Config.MAP_NAME)
		return nil
	end
	local slot = nextMapSlot
	nextMapSlot += 1
	local map  = (template :: Model):Clone() :: Model
	map.Name   = Config.MAP_NAME .. "_" .. player.Name
	map:PivotTo(CFrame.new(slot * 4000, 0, 5000))
	map.Parent = workspace
	return map
end

local function teleportToMap(player: Player, map: Model)
	local character = player.Character
	if character then
		local spawnPart = map:FindFirstChild("Spawn_In", true)
		if spawnPart and spawnPart:IsA("BasePart") then
			character:PivotTo((spawnPart :: BasePart).CFrame * CFrame.new(0, 5, 0))
		else
			character:PivotTo(map:GetPivot() * CFrame.new(0, 5, 0))
		end
	end
end

local function giveGun(player: Player)
	local template = ServerStorage:FindFirstChild(Config.GUN_NAME)
	if not template then
		warn("[WaveManager] Gun not found in ServerStorage: " .. Config.GUN_NAME)
		return
	end
	if not player.Backpack:FindFirstChild(Config.GUN_NAME) then
		template:Clone().Parent = player.Backpack
	end
end

local function cleanupPlayerZombies(playerName: string)
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "Zombie" and obj:GetAttribute("Owner") == playerName then
			obj:Destroy()
		end
	end
end

local function runWave(player: Player, waveNumber: number, spawnPos: Vector3, waveEvent: RemoteEvent, humanoid: Humanoid)
	print(string.format("[WaveManager] Wave %d started for %s (%d zombies).", waveNumber, player.Name, waveNumber))
	waveEvent:FireClient(player, waveNumber)

	local remaining = waveNumber
	local function onZombieDied() remaining -= 1 end

	for i = 1, waveNumber do
		if not player.Parent or humanoid.Health <= 0 then break end
		ZombieManager.spawn(player, onZombieDied, spawnPos)
		if i < waveNumber then
			task.wait(Config.WAVE_SPAWN_INTERVAL)
		end
	end

	while remaining > 0 and player.Parent and humanoid.Health > 0 do
		task.wait(0.5)
	end
end

function WaveManager.startBattle(player: Player, waveEvent: RemoteEvent, waveClearEvent: RemoteEvent): number
	local map = cloneMap(player)
	if not map then return 0 end

	local humanoid = getBattleHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		map:Destroy()
		return 0
	end

	teleportToMap(player, map)
	giveGun(player)

	local spawnPos   = findZombieSpawnPosition(map)
	local waveNumber = Config.STARTING_WAVE

	-- Use the captured humanoid reference throughout; player.Character changes on respawn
	-- but this humanoid's Health stays 0 after death, so the loop detects death correctly.
	while player.Parent and humanoid.Health > 0 do
		runWave(player, waveNumber, spawnPos, waveEvent, humanoid)

		if humanoid.Health <= 0 then
			print(string.format("[WaveManager] %s died on wave %d.", player.Name, waveNumber))
			cleanupPlayerZombies(player.Name)
			break
		end

		print(string.format("[WaveManager] Wave %d cleared! Next in %ds.", waveNumber, Config.WAVE_BETWEEN_DELAY))
		waveClearEvent:FireClient(player)
		task.wait(Config.WAVE_BETWEEN_DELAY)
		waveNumber += 1
	end

	map:Destroy()
	print("[WaveManager] DEBUG: map destroyed for " .. player.Name)
	return waveNumber
end

return WaveManager
