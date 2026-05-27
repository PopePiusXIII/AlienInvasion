--!strict
--------------------------------------------------------------------------------
-- MatchQueueService.luau  (lobby/src/server/services)
-- Manages the cross-server player queue using MemoryStoreService SortedMap.
-- Single Responsibility: MemoryStore read/write for the matchmaking queue.
--
-- Race-condition note: two lobby servers polling simultaneously could both read
-- the same top-N entries before either removes them. This is structurally rare
-- at QUEUE_POLL_RATE intervals; MatchmakingService mitigates it by validating
-- that matched UserIds are still online before initiating the teleport.
--
-- Public API:
--   MatchQueueService.enqueue(player)      → boolean (success)
--   MatchQueueService.dequeue(player)
--   MatchQueueService.tryFormMatch()       → { { userId, name } }? or nil
--------------------------------------------------------------------------------

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)

local TAG = "MatchQueueService"

local MatchQueueService = Framework.CreateService({ Name = TAG })

local EXPIRY_SECONDS = 120   -- auto-expire stale queue entries after 2 minutes

local _queueMap: MemoryStoreSortedMap

function MatchQueueService:Init()
	_queueMap = MemoryStoreService:GetSortedMap(Config.MEMORY_STORE_NAME)
	Logger.info(TAG, "MemoryStore map '%s' initialized.", Config.MEMORY_STORE_NAME)
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Add a player to the global cross-server queue.
--- Returns true on success; false if the MemoryStore call fails.
function MatchQueueService.enqueue(player: Player): boolean
	local ok, err = pcall(function()
		_queueMap:SetAsync(
			tostring(player.UserId),
			{ userId = player.UserId, name = player.Name },
			EXPIRY_SECONDS,
			os.time()  -- sort key: monotonically increasing → FIFO ordering
		)
	end)
	if not ok then
		Logger.warn(TAG, "Enqueue failed for %s: %s", player.Name, tostring(err))
		return false
	end
	Logger.info(TAG, "%s added to queue.", player.Name)
	return true
end

--- Remove a specific player from the global queue (cancelled or disconnected).
function MatchQueueService.dequeue(player: Player)
	local ok, err = pcall(function()
		_queueMap:RemoveAsync(tostring(player.UserId))
	end)
	if not ok then
		Logger.warn(TAG, "Dequeue failed for %s: %s", player.Name, tostring(err))
	else
		Logger.info(TAG, "%s removed from queue.", player.Name)
	end
end

--- Attempt to form a match by reading the oldest MATCH_SIZE entries.
--- On success, removes them from the map and returns their data.
--- Returns nil if there are fewer than MATCH_SIZE players in the queue.
function MatchQueueService.tryFormMatch(): { any }?
	local entries: { any }?
	local ok, err = pcall(function()
		entries = _queueMap:GetRangeAsync(Enum.SortDirection.Ascending, Config.MATCH_SIZE)
	end)
	if not ok then
		Logger.warn(TAG, "GetRangeAsync failed: %s", tostring(err))
		return nil
	end
	if not entries or #entries < Config.MATCH_SIZE then
		return nil
	end

	-- Remove matched entries atomically (best-effort; race condition is low-frequency).
	for _, entry in ipairs(entries) do
		pcall(function() _queueMap:RemoveAsync(entry.key) end)
	end

	local matched: { any } = {}
	for _, entry in ipairs(entries) do
		table.insert(matched, entry.value)
	end
	Logger.info(TAG, "Match formed with %d players.", #matched)
	return matched
end

return MatchQueueService
