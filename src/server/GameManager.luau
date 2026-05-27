--!strict
local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local TeleportService   = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config      = require(ReplicatedStorage.Shared.Config)
local WaveManager = require(script.Parent.WaveManager)

local GameManager = {}

export type MatchState = "WAITING" | "ACTIVE" | "ENDED"
local matchState: MatchState = "WAITING"

local statsStore = DataStoreService:GetDataStore(Config.DATA_STORE_NAME)

local function saveStats(player: Player, waveReached: number)
	local key = "player_" .. tostring(player.UserId)
	local ok, err = pcall(function()
		statsStore:UpdateAsync(key, function(existing: any?)
			local data = existing or { bestWave = 0, totalGames = 0 }
			data.bestWave   = math.max(data.bestWave, waveReached)
			data.totalGames = data.totalGames + 1
			return data
		end)
	end)
	if not ok then
		warn("[GameManager] DataStore save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function returnAllToLobby()
	local players = Players:GetPlayers()
	if #players == 0 then return end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(Config.LOBBY_PLACE_ID, players)
	end)
	if not ok then
		warn("[GameManager] TeleportAsync to lobby failed: " .. tostring(err))
	end
end

function GameManager.getState(): MatchState
	return matchState
end

-- Launches one battle per connected player concurrently.
-- Saves stats and returns everyone to the Lobby once all battles finish.
function GameManager.startMatch(waveEvent: RemoteEvent)
	if matchState ~= "WAITING" then
		warn("[GameManager] startMatch ignored — state is already " .. matchState)
		return
	end

	matchState = "ACTIVE"
	local players = Players:GetPlayers()
	if #players == 0 then matchState = "ENDED"; return end

	local remaining = #players
	print(string.format("[GameManager] Match ACTIVE with %d players.", remaining))

	for _, player in ipairs(players) do
		task.spawn(function()
			local waveReached: number = WaveManager.startBattle(player, waveEvent)
			saveStats(player, waveReached)

			-- Luau cooperative scheduling makes this decrement safe (no true parallelism).
			remaining -= 1
			print(string.format("[GameManager] %s finished on wave %d. %d player(s) remaining.",
				player.Name, waveReached, remaining))

			if remaining <= 0 and matchState == "ACTIVE" then
				matchState = "ENDED"
				print("[GameManager] Match ENDED. Returning to lobby in 5s.")
				task.delay(5, returnAllToLobby)
			end
		end)
	end
end

return GameManager
