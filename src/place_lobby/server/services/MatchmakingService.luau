--!strict
--------------------------------------------------------------------------------
-- MatchmakingService.luau  (places/lobby/src/server/services)
-- Owns: per-server queuedPlayers table, JoinQueue/LeaveQueue/MatchFound remotes,
-- and the polling loop that forms and teleports matches.
-- Single Responsibility: queue state management and match orchestration.
--
-- Depends on MatchQueueService (MemoryStore I/O) and TeleportHelperService.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework              = require(ReplicatedStorage.Shared.Framework)
local Logger                 = require(ReplicatedStorage.Shared.Logger)
local Config                 = require(ReplicatedStorage.Shared.Config)
local RemoteNames            = require(ReplicatedStorage.Shared.RemoteNames)
local MatchQueueService      = require(script.Parent.MatchQueueService)
local TeleportHelperService  = require(script.Parent.TeleportHelperService)

local TAG = "MatchmakingService"

local MatchmakingService = Framework.CreateService({ Name = TAG })

-- Per-server in-memory map: UserId → Player.
-- Tracks which players on THIS server have entered the queue
-- (MatchQueueService tracks the global cross-server queue).
local _localQueue: { [number]: Player } = {}

local _matchFoundRemote: RemoteEvent

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function MatchmakingService:Init()
	local joinQueueRemote  = Framework.CreateRemote(RemoteNames.JOIN_QUEUE)
	local leaveQueueRemote = Framework.CreateRemote(RemoteNames.LEAVE_QUEUE)
	_matchFoundRemote      = Framework.CreateRemote(RemoteNames.MATCH_FOUND)

	Logger.wrapServerEvent(joinQueueRemote, TAG, function(player: Player)
		MatchmakingService._enqueue(player)
	end)
	Logger.wrapServerEvent(leaveQueueRemote, TAG, function(player: Player)
		MatchmakingService._dequeue(player)
	end)

	Logger.info(TAG, "Remotes registered.")
end

function MatchmakingService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		-- Auto-dequeue players who disconnect while waiting.
		MatchmakingService._dequeue(player)
	end)

	-- Matchmaking poll loop: runs for the lifetime of this server.
	task.spawn(function()
		while true do
			task.wait(Config.QUEUE_POLL_RATE)

			local matched = MatchQueueService.tryFormMatch()
			if not matched then continue end

			-- Resolve UserIds to Player objects; skip disconnected players.
			local toTeleport: { Player } = {}
			for _, data in ipairs(matched) do
				local p = Players:GetPlayerByUserId(data.userId)
				if p then
					table.insert(toTeleport, p)
					_localQueue[data.userId] = nil
				end
			end

			if #toTeleport == 0 then continue end

			Logger.info(TAG, "Match formed with %d player(s).", #toTeleport)

			-- Notify clients so they can show the "Match found!" countdown.
			for _, p in ipairs(toTeleport) do
				Logger.fireClient(_matchFoundRemote, p)
			end

			-- Short delay so players see the notification before the screen fades.
			task.delay(3, function()
				if Config.TEST_MODE then
					Logger.info(TAG, "TEST_MODE enabled: skipping teleport, re-queuing players.")
					for _, p in ipairs(toTeleport) do
						if p.Parent then
							MatchmakingService._enqueue(p)
						end
					end
				else
					local ok = TeleportHelperService.teleportToMatch(toTeleport)
					if not ok then
						Logger.warn(TAG, "Teleport failed. Re-queuing survivors.")
						for _, p in ipairs(toTeleport) do
							if p.Parent then  -- still connected
								MatchmakingService._enqueue(p)
							end
						end
					end
				end
			end)
		end
	end)

	Logger.info(TAG, "Matchmaking poll loop started (interval: %ds).", Config.QUEUE_POLL_RATE)
end

-- ── Private helpers ───────────────────────────────────────────────────────────

function MatchmakingService._enqueue(player: Player)
	if _localQueue[player.UserId] then return end
	local ok = MatchQueueService.enqueue(player)
	if ok then
		_localQueue[player.UserId] = player
	end
end

function MatchmakingService._dequeue(player: Player)
	if not _localQueue[player.UserId] then return end
	MatchQueueService.dequeue(player)
	_localQueue[player.UserId] = nil
end

return MatchmakingService
