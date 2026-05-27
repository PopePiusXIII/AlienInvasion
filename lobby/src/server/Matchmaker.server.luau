--!strict
-- ⚠️  DEPRECATED — logic moved to LobbyServerRuntime.server.luau + lobby/src/server/services/
-- This script is intentionally inert. Delete it after verifying LobbyServerRuntime works.
-- See: LobbyServerRuntime.server.luau, MatchmakingService, MatchQueueService, TeleportHelperService
return

local Config            = require(ReplicatedStorage.Shared.Config)
local MatchmakerService = require(script.Parent.MatchmakerService)
local TeleportHelper    = require(script.Parent.TeleportHelper)

-- ── RemoteEvents ──────────────────────────────────────────────────────────────

local joinQueueEvent  = Instance.new("RemoteEvent")
joinQueueEvent.Name   = "JoinQueue"
joinQueueEvent.Parent = ReplicatedStorage

local leaveQueueEvent  = Instance.new("RemoteEvent")
leaveQueueEvent.Name   = "LeaveQueue"
leaveQueueEvent.Parent = ReplicatedStorage

local matchFoundEvent  = Instance.new("RemoteEvent")
matchFoundEvent.Name   = "MatchFound"
matchFoundEvent.Parent = ReplicatedStorage

-- ── Local queue tracking (this lobby server instance) ──────────────────────

local queuedPlayers: { [number]: Player } = {}

local function isQueued(player: Player): boolean
	return queuedPlayers[player.UserId] ~= nil
end

local function enqueue(player: Player)
	if isQueued(player) then return end
	local ok = MatchmakerService.enqueue(player)
	if ok then
		queuedPlayers[player.UserId] = player
		print("[Matchmaker] " .. player.Name .. " joined the queue.")
	end
end

local function dequeue(player: Player)
	if not isQueued(player) then return end
	MatchmakerService.dequeue(player)
	queuedPlayers[player.UserId] = nil
	print("[Matchmaker] " .. player.Name .. " left the queue.")
end

-- ── Event handlers ────────────────────────────────────────────────────────────

joinQueueEvent.OnServerEvent:Connect(enqueue)
leaveQueueEvent.OnServerEvent:Connect(dequeue)

-- Auto-dequeue players who disconnect mid-wait
Players.PlayerRemoving:Connect(function(player)
	dequeue(player)
end)

-- ── Matchmaking loop ──────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(Config.QUEUE_POLL_RATE)

		local matched = MatchmakerService.tryFormMatch()
		if not matched then continue end

		-- Resolve UserIds → Player objects; skip anyone who disconnected
		local playersToTeleport: { Player } = {}
		for _, data in ipairs(matched) do
			local p = Players:GetPlayerByUserId(data.userId)
			if p then
				table.insert(playersToTeleport, p)
				queuedPlayers[data.userId] = nil
			end
		end

		if #playersToTeleport == 0 then continue end

		print(string.format("[Matchmaker] Match formed with %d player(s).", #playersToTeleport))

		-- Notify clients so they can show a "Match found!" countdown
		for _, p in ipairs(playersToTeleport) do
			matchFoundEvent:FireClient(p)
		end

		-- Short delay so clients can see the notification before the screen goes black
		task.delay(3, function()
			local success = TeleportHelper.teleportToMatch(playersToTeleport)
			if not success then
				-- Teleport failed: re-queue surviving players
				warn("[Matchmaker] Teleport failed. Re-queuing players.")
				for _, p in ipairs(playersToTeleport) do
					if p.Parent then  -- still connected
						enqueue(p)
					end
				end
			end
		end)
	end
end)
