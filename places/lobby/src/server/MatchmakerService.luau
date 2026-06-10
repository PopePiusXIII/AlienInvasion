--!strict
-- MatchmakerService.luau  (Lobby Place — ServerScriptService)
-- Manages the cross-server player queue using MemoryStoreService SortedMap.
-- Key   = UserId string  (allows per-player removal when they leave the queue)
-- Value = { userId, name }
-- SortKey = os.time() timestamp  (FIFO ordering)
--
-- Race-condition note: two lobby servers polling simultaneously could both read
-- the same top-N entries before either removes them. This is rare at QUEUE_POLL_RATE
-- intervals; Matchmaker.server.luau mitigates it by validating that matched
-- UserIds are still online before teleporting.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MatchmakerService = {}

local EXPIRY_SECONDS = 120  -- auto-expire queue entries after 2 minutes

local queueMap = MemoryStoreService:GetSortedMap(Config.MEMORY_STORE_NAME)

-- Add a player to the global queue.
-- Returns true on success.
function MatchmakerService.enqueue(player: Player): boolean
	local ok, err = pcall(function()
		queueMap:SetAsync(
			tostring(player.UserId),
			{ userId = player.UserId, name = player.Name },
			EXPIRY_SECONDS,
			os.time()  -- sort key: monotonically increasing for FIFO
		)
	end)
	if not ok then
		warn("[MatchmakerService] Enqueue failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end
	return true
end

-- Remove a specific player from the global queue (e.g. they cancelled or disconnected).
function MatchmakerService.dequeue(player: Player)
	local ok, err = pcall(function()
		queueMap:RemoveAsync(tostring(player.UserId))
	end)
	if not ok then
		warn("[MatchmakerService] Dequeue failed for " .. player.Name .. ": " .. tostring(err))
	end
end

-- Attempt to form a match by reading the oldest MATCH_SIZE entries.
-- Returns a list of player-data tables on success, or nil if not enough players.
function MatchmakerService.tryFormMatch(): { any }?
	local entries: { any }?
	local ok, err = pcall(function()
		entries = queueMap:GetRangeAsync(Enum.SortDirection.Ascending, Config.MATCH_SIZE)
	end)
	if not ok then
		warn("[MatchmakerService] GetRangeAsync failed: " .. tostring(err))
		return nil
	end
	if not entries or #entries < Config.MATCH_SIZE then
		return nil
	end

	-- Remove each matched entry from the global queue
	for _, entry in ipairs(entries) do
		pcall(function()
			queueMap:RemoveAsync(entry.key)
		end)
	end

	local matched: { any } = {}
	for _, entry in ipairs(entries) do
		table.insert(matched, entry.value)
	end
	return matched
end

return MatchmakerService
