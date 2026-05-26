local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config        = require(ReplicatedStorage.Shared.Config)
local ZombieManager = require(script.Parent.ZombieManager)

local WaveManager = {}

-- Loads the map into Workspace once, or returns the existing copy.
local function getMap()
	local existing = workspace:FindFirstChild(Config.MAP_NAME)
	if existing then return existing end

	local template = ServerStorage:FindFirstChild(Config.MAP_NAME)
	if not template then
		warn("[WaveManager] Map not found in ServerStorage: " .. Config.MAP_NAME)
		return nil
	end

	local map = template:Clone()
	map:PivotTo(CFrame.new(0, 0, 5000))
	map.Parent = workspace

	local spawnPart = map:FindFirstChild("Spawn_In", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		map.PrimaryPart = spawnPart
	end

	print("[WaveManager] Map loaded.")
	return map
end

-- Polls every 0.5s until the player has a living character. Returns (character, humanoid).
local function waitForLiveCharacter(player)
	while player.Parent do
		local char = player.Character
		if char then
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			if hum and hum.Health > 0 then
				return char, hum
			end
		end
		task.wait(0.5)
	end
end

-- Main game loop for a single player.
function WaveManager.startForPlayer(player, waveEvent)
	local map = getMap()
	if not map then return end

	while player.Parent do
		-- LOBBY PHASE: poll until alive, then wait before sending to map
		local character, humanoid = waitForLiveCharacter(player)
		if not character then break end

		print("[WaveManager] " .. player.Name .. " in lobby. Teleporting in " .. Config.WAVE_START_DELAY .. "s.")
		task.wait(Config.WAVE_START_DELAY)

		-- Safety: still alive after the wait?
		if not player.Parent then break end
		if not character.Parent or humanoid.Health <= 0 then continue end

		-- BATTLE PHASE: teleport to map and run waves
		character:PivotTo(map:GetPivot() * CFrame.new(0, 5, 0))
		print("[WaveManager] Teleported " .. player.Name .. " to map.")

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
				end, map:GetPivot().Position)
				if i < waveNumber then
					task.wait(Config.WAVE_SPAWN_INTERVAL)
				end
			end

			-- Wait until all zombies die or player dies
			while zombiesRemaining > 0 and player.Parent and humanoid.Health > 0 do
				task.wait(0.5)
			end

			-- Player died: clean up and return to lobby
			if humanoid.Health <= 0 then
				print("[WaveManager] " .. player.Name .. " died. Cleaning up.")
				for _, obj in ipairs(workspace:GetChildren()) do
					if obj.Name == "Zombie" then obj:Destroy() end
				end
				break
			end

			-- Wave cleared: next wave
			print(string.format("[WaveManager] Wave %d cleared! Next in %ds.", waveNumber, Config.WAVE_BETWEEN_DELAY))
			task.wait(Config.WAVE_BETWEEN_DELAY)
			waveNumber += 1
		end
	end
end

return WaveManager
