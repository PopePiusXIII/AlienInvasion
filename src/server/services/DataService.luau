--!strict
--------------------------------------------------------------------------------
-- DataService.luau  (src/server/services)
-- Handles all DataStore I/O. No game logic lives here.
-- Single Responsibility: persistent player data read/write.
--
-- Public API:
--   DataService.saveStats(player, waveReached)
--     Atomically updates bestWave and totalGames via UpdateAsync.
--------------------------------------------------------------------------------

local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)

local TAG = "DataService"

local DataService = Framework.CreateService({ Name = TAG })

local _statsStore: DataStore

function DataService:Init()
	_statsStore = DataStoreService:GetDataStore(Config.DATA_STORE_NAME)
	Logger.info(TAG, "DataStore '%s' initialized.", Config.DATA_STORE_NAME)
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Persist the wave reached for a player.
--- Uses UpdateAsync for atomic read-modify-write — safe for concurrent callers.
function DataService.saveStats(player: Player, waveReached: number)
	local key = "player_" .. tostring(player.UserId)
	local ok, err = pcall(function()
		_statsStore:UpdateAsync(key, function(existing: any?)
			local data = existing or { bestWave = 0, totalGames = 0 }
			data.bestWave   = math.max(data.bestWave, waveReached)
			data.totalGames = data.totalGames + 1
			return data
		end)
	end)
	if not ok then
		Logger.warn(TAG, "Save failed for %s (wave %d): %s", player.Name, waveReached, tostring(err))
	else
		Logger.info(TAG, "Saved stats for %s — wave %d.", player.Name, waveReached)
	end
end

return DataService
