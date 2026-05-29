--!strict
--------------------------------------------------------------------------------
-- PlayerService.luau  (src/server/services)
-- Single source of truth for the per-player active state.
-- Owns: activePlayers table, lobby spawn logic, RequestPlay RemoteEvent.
-- Orchestrates the startBattle → DataService.saveStats pipeline.
--
-- Single Responsibility: player lifecycle and battle entry gating.
-- GameService calls PlayerService.isActive() to query state without coupling
-- to the internal activePlayers table.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework    = require(ReplicatedStorage.Shared.Framework)
local Logger       = require(ReplicatedStorage.Shared.Logger)
local Config       = require(ReplicatedStorage.Shared.Config)
local RemoteNames  = require(ReplicatedStorage.Shared.RemoteNames)
-- These are required at module-level; both are already cached by the time
-- ServerRuntime requires PlayerService (dependency order: Zombie→Wave→Data→Player).
local WaveService  = require(script.Parent.WaveService)
local DataService  = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlayerSpawnModule = require(script.Parent.modules.player.PlayerSpawnModule)
local PlayerEntryGateModule = require(script.Parent.modules.player.PlayerEntryGateModule)

local TAG = "PlayerService"

local PlayerService = Framework.CreateService({ Name = TAG })

-- Single source of truth: which players are currently in an active battle.
-- Accessed only through the public isActive() accessor outside this service.
local _activePlayers: { [Player]: boolean } = {}

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function PlayerService:Init()
	local requestPlayRemote = Framework.CreateRemote(RemoteNames.REQUEST_PLAY)

	Logger.wrapServerEvent(requestPlayRemote, TAG, function(player: Player)
		PlayerService._onRequestPlay(player)
	end)

	Logger.info(TAG, "RequestPlay handler registered.")
end

function PlayerService:Start()
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			PlayerSpawnModule.spawnAtLobby(character, Config.LOBBY_NAME)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		-- Release the active slot immediately so no ghost entry persists.
		_activePlayers[player] = nil
	end)

	-- Handle players who joined before this service started (Studio edge-case).
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(character: Model)
			PlayerSpawnModule.spawnAtLobby(character, Config.LOBBY_NAME)
		end)
		if player.Character then
			PlayerSpawnModule.spawnAtLobby(player.Character, Config.LOBBY_NAME)
		end
	end

	Logger.info(TAG, "Player lifecycle listeners connected.")
end

-- ── Private helpers ───────────────────────────────────────────────────────────

function PlayerService._onRequestPlay(player: Player)
	Logger.verbose(TAG, "RequestPlay from %s — currently active: %s",
		player.Name, tostring(_activePlayers[player] ~= nil))

	if not PlayerEntryGateModule.isEligibleToPlay(_activePlayers, player) then
		Logger.info(TAG, "RequestPlay rejected for %s (already active or dead).", player.Name)
		return
	end

	_activePlayers[player] = true

	task.spawn(function()
		-- startBattle yields until the battle ends.
		local waveReached = WaveService.startBattle(player)
		Logger.info(TAG, "%s finished on wave %d.", player.Name, waveReached)

		-- Save regardless of how the battle ended (death, disconnect, etc.).
		local economySummary = EconomyService.finalizeRun(player)
		DataService.saveStats(player, waveReached, economySummary)

		-- Release the slot so the player can queue again.
		_activePlayers[player] = nil
		Logger.info(TAG, "Battle slot released for %s.", player.Name)
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Returns true if [player] is currently in an active battle.
--- Read-only; the internal table is not exposed.
function PlayerService.isActive(player: Player): boolean
	return _activePlayers[player] == true
end

return PlayerService
