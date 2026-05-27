local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config        = require(ReplicatedStorage.Shared.Config)
local ZombieManager = require(script.Parent.ZombieManager)

local WaveManager = {}

-- Each player gets their own map clone placed at a unique world position.
local nextMapSlot = 0

local function createPlayerMap(player)
	local template = ServerStorage:FindFirstChild(Config.MAP_NAME)
	if not template then
		warn("[WaveManager] Map not found in ServerStorage: " .. Config.MAP_NAME)
		return nil
	end

	local slot = nextMapSlot
	nextMapSlot += 1

	local map = template:Clone()
	map.Name = Config.MAP_NAME .. "_" .. player.Name
	map:PivotTo(CFrame.new(slot * 4000, 0, 5000))
	map.Parent = workspace

	local spawnPart = map:FindFirstChild("Spawn_In", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		map.PrimaryPart = spawnPart
	end

	print("[WaveManager] Map created for " .. player.Name .. " at slot " .. slot)
	return map
end

-- Teleports the player to the map, gives the gun, and runs the full wave loop.
-- Called by Main.server when the player confirms play via the lobby pad.
function WaveManager.startBattle(player, waveEvent)
	local map = createPlayerMap(player)
	if not map then return end

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- Find the zombie spawn point; fall back to map centre if the part is missing
	local spawnMobPart = map:FindFirstChild("Spawn_Mob", true)
	local zombieSpawnPos = spawnMobPart and spawnMobPart.Position or map:GetPivot().Position

	-- Teleport to map
	character:PivotTo(map:GetPivot() * CFrame.new(0, 5, 0))
	print("[WaveManager] Teleported " .. player.Name .. " to map.")

	-- Give the gun; it lives in ServerStorage so the lobby stays weapon-free
	local gunTemplate = ServerStorage:FindFirstChild(Config.GUN_NAME)
	if gunTemplate then
		if not player.Backpack:FindFirstChild(Config.GUN_NAME) then
			gunTemplate:Clone().Parent = player.Backpack
			print("[WaveManager] Gave " .. Config.GUN_NAME .. " to " .. player.Name)
		end
	else
		warn("[WaveManager] Gun '" .. Config.GUN_NAME .. "' not found in ServerStorage.")
	end

	-- Wave loop
	local waveNumber = Config.STARTING_WAVE
	while player.Parent and humanoid.Health > 0 do
		local zombiesRemaining = waveNumber
		print(string.format("[WaveManager] Wave %d: spawning %d zombies.", waveNumber, waveNumber))
		waveEvent:FireClient(player, waveNumber)

		-- Spawn all zombies for this wave
		for i = 1, waveNumber do
			if not player.Parent or humanoid.Health <= 0 then break end
			ZombieManager.spawn(player, function()
				zombiesRemaining -= 1
			end, zombieSpawnPos)
			if i < waveNumber then
				task.wait(Config.WAVE_SPAWN_INTERVAL)
			end
		end

		-- Wait until all zombies die or player dies
		while zombiesRemaining > 0 and player.Parent and humanoid.Health > 0 do
			task.wait(0.5)
		end

		-- Player died: clean up only this player's zombies
		if humanoid.Health <= 0 then
			print("[WaveManager] " .. player.Name .. " died. Cleaning up.")
			for _, obj in ipairs(workspace:GetChildren()) do
				if obj.Name == "Zombie" and obj:GetAttribute("Owner") == player.Name then
					obj:Destroy()
				end
			end
			break
		end

		-- Wave cleared: next wave
		print(string.format("[WaveManager] Wave %d cleared! Next in %ds.", waveNumber, Config.WAVE_BETWEEN_DELAY))
		task.wait(Config.WAVE_BETWEEN_DELAY)
		waveNumber += 1
	end

	-- Always destroy this player's map when the battle ends (death or disconnect)
	if map.Parent then
		map:Destroy()
		print("[WaveManager] Destroyed map for " .. player.Name)
	end

	return waveNumber  -- tells GameManager how far this player reached
end

return WaveManager
