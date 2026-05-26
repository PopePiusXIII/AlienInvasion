-- Manages the wave loop for a single player.
-- Each wave spawns one additional zombie compared to the last.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config        = require(ReplicatedStorage.Shared.Config)
local ZombieManager = require(script.Parent.ZombieManager)

local WaveManager = {}

-- Starts an infinite wave loop for `player`.
-- Fires `waveEvent` to that client at the start of each wave.
function WaveManager.startForPlayer(player, waveEvent)
	local waveNumber = 0

	while player.Parent do  -- exits cleanly if the player leaves
		waveNumber += 1
		local zombiesRemaining = waveNumber

		print(string.format(
			"[WaveManager] Wave %d started for %s (%d zombies)",
			waveNumber, player.Name, waveNumber
		))

		waveEvent:FireClient(player, waveNumber)

		-- Spawn zombies one at a time with a gap between each
		for i = 1, waveNumber do
			if not player.Parent then return end
			task.wait(Config.WAVE_SPAWN_INTERVAL)
			ZombieManager.spawn(player, function()
				zombiesRemaining -= 1
			end)
		end

		-- Wait until every zombie in this wave is dead
		while zombiesRemaining > 0 do
			task.wait(1)
		end

		print(string.format(
			"[WaveManager] Wave %d complete. Next wave in %ds.",
			waveNumber, Config.WAVE_BETWEEN_DELAY
		))

		task.wait(Config.WAVE_BETWEEN_DELAY)
	end
end

return WaveManager
