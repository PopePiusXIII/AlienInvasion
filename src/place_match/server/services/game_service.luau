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
local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework    = require(replicated_storage.common.shared.framework)
local Logger       = require(replicated_storage.common.shared.logger)
local GameConfig       = require(replicated_storage.match.shared.configs.game_config)
local ProfileService = require(server_script_service.common.services.profile_db)
local LevelService = require(server_script_service.match.services.level_service)
local EconomyService = require(server_script_service.match.services.economy_service)
local RNGService = require(server_script_service.match.services.rng_service)
local MatchAutoStartModule = require(server_script_service.match.modules.game.match_auto_start_module)
local MatchReturnModule = require(server_script_service.match.modules.game.match_return_module)

local TAG = "GameService"
local GameService = {}
GameService.Name = TAG

export type MatchState = "WAITING" | "ACTIVE" | "ENDED"
local _matchState: MatchState = "WAITING"

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function GameService:Init()
	Logger.info(TAG, "Initialized. State: WAITING.")
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Teleport all connected players back to the Lobby place.
function GameService._returnAllToLobby()
	MatchReturnModule.returnAllToLobby(TeleportService, GameConfig.LOBBY_PLACE_ID, Players, function(message: string, ...: any)
		Logger.warn(TAG, message, ...)
	end)
end

local function runActiveMatch(players: { Player })
	local fluxTierReached = LevelService.startMatch(players)

	for _, player in ipairs(players) do
		local economySummary = EconomyService.finalizeRun(player)
		ProfileService.saveStats(player, fluxTierReached, economySummary)
		Logger.info(TAG, "%s done at shared flux tier %d.", player.Name, fluxTierReached)
	end

	if (_matchState :: string) == "ACTIVE" then
		_matchState = "ENDED"
		Logger.info(TAG, "Match ENDED. Returning to lobby in 5s.")
		task.delay(5, GameService._returnAllToLobby)
	end
end

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

	Logger.info(TAG, "Match ACTIVE with %d players.", #players)
	task.spawn(runActiveMatch, players)
end

function GameService.getState(): MatchState
	return _matchState
end

function GameService:Start()
	task.spawn(function()
		local shouldStart = MatchAutoStartModule.waitForMatchStart(
			Players,
			GameConfig.MATCH_SIZE,
			GameConfig.MATCH_WAIT_TIMEOUT
		)
		if not shouldStart then return end

		if _matchState ~= "WAITING" then
			-- The GoToGame pad already started the match; do nothing.
			return
		end
		if #Players:GetPlayers() == 0 then return end

		Logger.info(TAG, "Auto-starting with %d/%d players.",
			#Players:GetPlayers(), GameConfig.MATCH_SIZE)
		GameService.startMatch()
	end)
end

GameService = Framework.CreateService(GameService)
return GameService
