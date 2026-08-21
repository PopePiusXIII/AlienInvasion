--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)
local FluxConfig = require(replicated_storage.match.shared.configs.flux_config)
local WaveTypes = require(replicated_storage.match.shared.types.wave_types)
local CharacterService = require(server_script_service.match.services.character_service)
local EconomyService = require(server_script_service.match.services.economy_service)
local FluxService = require(server_script_service.match.services.flux_service)
local PowerupService = require(server_script_service.match.services.powerup_service)
local ZombieService = require(server_script_service.match.services.zombie_service)

local TAG = "LevelService"

type MatchState = WaveTypes.MatchState

local _levelContinuePromptRemote: RemoteEvent
local _levelContinuePromptClosedRemote: RemoteEvent
local _levelContinueVoteRemote: RemoteEvent
local _matchState: MatchState? = nil

local function isParticipantAlive(match: MatchState, player: Player): boolean
	local humanoid = match.participantHumanoids[player]
	return player.Parent ~= nil and humanoid.Parent ~= nil and humanoid.Health > 0
end

local function onLevelContinueVote(player: Player, wantsToContinue: any)
	local match = _matchState
	if not match or not match.voteOpen or not match.eligibleVoters[player] or player.Parent == nil then
		return
	end
	if type(wantsToContinue) ~= "boolean" then
		Logger.warn(TAG, "Ignoring invalid level vote from %s.", player.Name)
		return
	end
	if match.votesByPlayer[player] ~= nil then
		return
	end
	match.votesByPlayer[player] = wantsToContinue
end

local function closeVote(match: MatchState, result: boolean): boolean
	match.voteOpen = false
	Logger.fireAllClients(_levelContinuePromptClosedRemote)
	return result
end

local function requestLevelContinuation(match: MatchState, nextLevelId: string): boolean
	table.clear(match.eligibleVoters)
	table.clear(match.votesByPlayer)
	for _, player in ipairs(match.participants) do
		if isParticipantAlive(match, player) then
			match.eligibleVoters[player] = true
		end
	end

	assert(next(match.eligibleVoters) ~= nil, "[LevelService] Cannot request continuation without an eligible voter.")
	match.voteOpen = true
	for player in pairs(match.eligibleVoters) do
		Logger.fireClient(_levelContinuePromptRemote, player, nextLevelId, FluxConfig.LEVEL_CONTINUE_VOTE_TIMEOUT)
	end

	local deadline = os.clock() + FluxConfig.LEVEL_CONTINUE_VOTE_TIMEOUT
	while match.running and os.clock() < deadline do
		local allVotedContinue = true
		for player in pairs(match.eligibleVoters) do
			local vote = match.votesByPlayer[player]
			if vote == false then
				return closeVote(match, false)
			end
			if vote ~= true then
				allVotedContinue = false
			end
		end
		if allVotedContinue then
			return closeVote(match, true)
		end
		task.wait(0.1)
	end

	return closeVote(match, false)
end

local function beginParticipantRuns(match: MatchState)
	for _, player in ipairs(match.participants) do
		EconomyService.beginRun(player)
		PowerupService.beginBattle(player)
	end
end

local function endParticipantRuns(match: MatchState)
	for _, player in ipairs(match.participants) do
		ZombieService.cleanupForPlayer(player.Name)
		PowerupService.endBattle(player)
	end
end

local function initializeLevelService()
	assert(FluxConfig.LEVEL_CONTINUE_VOTE_TIMEOUT > 0,
		"[LevelService] LEVEL_CONTINUE_VOTE_TIMEOUT must be positive.")
	assert(#FluxConfig.LEVEL_ORDER > 0, "[LevelService] Flux configuration must define at least one level.")
	_levelContinuePromptRemote = Framework.CreateRemote("LevelContinuePrompt")
	_levelContinuePromptClosedRemote = Framework.CreateRemote("LevelContinuePromptClosed")
	_levelContinueVoteRemote = Framework.CreateRemote("LevelContinueVote")
	Logger.onServerEvent(_levelContinueVoteRemote, TAG, onLevelContinueVote)
end

local function startLevelService() end

local LevelService = Framework.CreateService({
	Name = TAG,
	Init = initializeLevelService,
	Start = startLevelService,
})

function LevelService.startMatch(participants: { Player }): number
	assert(_matchState == nil, "[LevelService] A level run is already active.")
	assert(#participants > 0, "[LevelService] Cannot start a level run without participants.")

	local participantHumanoids: { [Player]: Humanoid } = {}
	for _, player in ipairs(participants) do
		assert(player.Parent ~= nil, "[LevelService] Cannot start a level run for a disconnected player: " .. player.Name)
		participantHumanoids[player] = CharacterService.waitFor(player).humanoid
	end

	local match: MatchState = {
		participants = participants,
		participantHumanoids = participantHumanoids,
		kills = 0,
		aliveCount = 0,
		activeLevelIndex = 1,
		activeTierIndex = 0,
		highestTierReached = 0,
		nextOwnerIndex = 1,
		lastSpawnTime = -math.huge,
		queue = {},
		running = true,
		voteOpen = false,
		eligibleVoters = {},
		votesByPlayer = {},
		timer = {
			expired = false,
			stopped = false,
		},
	}
	_matchState = match
	Logger.info(TAG, "Starting level run for %d participants.", #participants)
	beginParticipantRuns(match)

	while match.running do
		local levelId = FluxConfig.LEVEL_ORDER[match.activeLevelIndex]
		local level = FluxConfig.LEVELS[levelId]
		assert(level ~= nil, "[LevelService] Active level is not configured: " .. tostring(levelId))
		Logger.info(TAG, "Starting level %s.", levelId)

		local completedLevel = FluxService.runLevel(match, level)
		if not completedLevel then
			break
		end

		local nextLevelIndex = match.activeLevelIndex + 1
		local nextLevelId = FluxConfig.LEVEL_ORDER[nextLevelIndex]
		if nextLevelId == nil then
			Logger.info(TAG, "Completed final configured level %s.", levelId)
			break
		end
		if not requestLevelContinuation(match, nextLevelId) then
			break
		end
		match.activeLevelIndex = nextLevelIndex
	end

	match.running = false
	match.timer.stopped = true
	endParticipantRuns(match)
	_matchState = nil
	Logger.info(TAG, "Final shared flux tier: %d.", match.highestTierReached)
	return match.highestTierReached
end

return LevelService