--!strict
--------------------------------------------------------------------------------
-- GameService.luau  (src/server/services)
-- Match-level orchestration for the Match Place.
-- In production (non-Studio), auto-starts a match once enough players arrive.
-- In Studio, suppressed — use the GoToGame pad via PlayerService instead.
--
-- Absorbs the logic that was previously split across Main.server.luau and
-- MatchInit.server.luau, eliminating the race condition where MatchInit could
-- call GameManager.startMatch() while Main was still setting up remotes.
--
-- Single Responsibility: match state machine and end-of-match teleport.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local TeleportService   = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework    = require(ReplicatedStorage.Shared.Framework)
local Logger       = require(ReplicatedStorage.Shared.Logger)
local Config       = require(ReplicatedStorage.Shared.Config)
local WaveService  = require(script.Parent.WaveService)
local DataService  = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MatchAutoStartModule = require(script.Parent.modules.game.MatchAutoStartModule)
local MatchReturnModule = require(script.Parent.modules.game.MatchReturnModule)

local TAG = "GameService"

export type MatchState = "WAITING" | "ACTIVE" | "ENDED"

local GameService = Framework.CreateService({ Name = TAG })

local _matchState: MatchState = "WAITING"

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function GameService:Init()
	Logger.info(TAG, "Initialized. State: WAITING.")
end

function GameService:Start()
	task.spawn(function()
		local shouldStart = MatchAutoStartModule.waitForMatchStart(
			Players,
			Config.MATCH_SIZE,
			Config.MATCH_WAIT_TIMEOUT
		)
		if not shouldStart then return end

		if _matchState ~= "WAITING" then
			-- The GoToGame pad already started the match; do nothing.
			return
		end
		if #Players:GetPlayers() == 0 then return end

		Logger.info(TAG, "Auto-starting with %d/%d players.",
			#Players:GetPlayers(), Config.MATCH_SIZE)
		GameService.startMatch()
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Launch one concurrent battle per connected player.
--- Saves stats and teleports everyone back to the Lobby once all battles finish.
function GameService.startMatch()
	if _matchState ~= "WAITING" then
		Logger.warn(TAG, "startMatch ignored — state is already '%s'.", _matchState)
		return
	end

	_matchState = "ACTIVE"
	local players = Players:GetPlayers()
	if #players == 0 then
		_matchState = "ENDED"
		return
	end

	-- Cooperative scheduling in Luau means the decrement below is safe; there
	-- is no true parallelism between task.spawn threads on the same server.
	local remaining = #players
	Logger.info(TAG, "Match ACTIVE with %d players.", remaining)

	for _, player in ipairs(players) do
		task.spawn(function()
			local waveReached = WaveService.startBattle(player)
			local economySummary = EconomyService.finalizeRun(player)
			DataService.saveStats(player, waveReached, economySummary)

			remaining -= 1
			Logger.info(TAG, "%s done on wave %d. %d player(s) remaining.",
				player.Name, waveReached, remaining)

			if remaining <= 0 and _matchState == "ACTIVE" then
				_matchState = "ENDED"
				Logger.info(TAG, "Match ENDED. Returning to lobby in 5s.")
				task.delay(5, GameService._returnAllToLobby)
			end
		end)
	end
end

function GameService.getState(): MatchState
	return _matchState
end

--- Teleport all connected players back to the Lobby place.
function GameService._returnAllToLobby()
	MatchReturnModule.returnAllToLobby(TeleportService, Config.LOBBY_PLACE_ID, Players, function(message: string, ...: any)
		Logger.warn(TAG, message, ...)
	end)
end

return GameService
