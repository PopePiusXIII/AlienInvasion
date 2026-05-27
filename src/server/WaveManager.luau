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

-- Teleports the player to the map, gives the gun, and runs the full wave loop.
-- Called by Main.server when the player confirms play via the lobby pad.
function WaveManager.startBattle(player, waveEvent)
	local map = getMap()
	if not map then return end

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

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
			return
		end

		-- Wave cleared: next wave
		print(string.format("[WaveManager] Wave %d cleared! Next in %ds.", waveNumber, Config.WAVE_BETWEEN_DELAY))
		task.wait(Config.WAVE_BETWEEN_DELAY)
		waveNumber += 1
	end
end

return WaveManager
