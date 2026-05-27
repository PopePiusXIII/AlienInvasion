--!strict
-- MatchInit.server.luau
-- Runs in the Match Place alongside Main.server.luau.
-- Auto-starts the match when players arrive via matchmaking (TeleportService).
-- In Studio or dev/test mode the GoToGame pad (Main.server.luau) still works;
-- MatchInit does nothing in Studio (TeleportService/MemoryStoreService unavailable).

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Skip auto-start entirely in Studio; use the GoToGame pad for testing instead.
if RunService:IsStudio() then return end

local Config      = require(ReplicatedStorage.Shared.Config)
local GameManager = require(script.Parent.GameManager)

-- WaveAnnounce is created by Main.server.luau; wait up to 30 s for it.
local waveEvent = ReplicatedStorage:WaitForChild("WaveAnnounce", 30) :: RemoteEvent

task.spawn(function()
	-- Poll until the expected number of players have joined, or until the
	-- safety timeout expires (handles late-joining players and network lag).
	local deadline = os.clock() + Config.MATCH_WAIT_TIMEOUT
	while os.clock() < deadline do
		if #Players:GetPlayers() >= Config.MATCH_SIZE then break end
		task.wait(1)
	end

	-- Do not interfere if the game was already started via the GoToGame pad.
	if GameManager.getState() ~= "WAITING" then return end
	if #Players:GetPlayers() == 0 then return end

	print(string.format("[MatchInit] Auto-starting match with %d/%d players.",
		#Players:GetPlayers(), Config.MATCH_SIZE))

	GameManager.startMatch(waveEvent)
end)
