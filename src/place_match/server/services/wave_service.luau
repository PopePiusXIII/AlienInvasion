--!strict
--------------------------------------------------------------------------------
-- WaveService.luau  (src/server/services)
-- Owns the match-level zombie flux lifecycle and shared spawn cue.
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)
local FluxConfig = require(replicated_storage.match.shared.configs.flux_config)
local ZombieConfig = require(replicated_storage.match.shared.configs.zombie_config)
local CharacterService = require(server_script_service.match.services.character_service)
local ZombieService = require(server_script_service.match.services.zombie_service)
local EconomyService = require(server_script_service.match.services.economy_service)
local PowerupService = require(server_script_service.match.services.powerup_service)

local TAG = "WaveService"

export type CueEntry = {
	zombieType: string,
	spawnPointName: string,
	amount: number,
}

type WeightedCueEntry = {
	zombieType: string,
	spawnPointName: string,
	amount: number,
	weight: number,
}

type FluxTier = {
	startTimeSeconds: number,
	maxAlive: number,
	entryCue: { CueEntry },
	randomCue: { WeightedCueEntry },
}

type MatchTimer = {
	expired: boolean,
	stopped: boolean,
}

type SpawnJob = {
	id: number,
	zombieType: string,
	spawnPointName: string,
}

type MatchState = {
	participants: { Player },
	participantHumanoids: { [Player]: Humanoid },
	kills: number,
	aliveCount: number,
	activeTierIndex: number,
	highestTierReached: number,
	nextJobId: number,
	nextOwnerIndex: number,
	lastSpawnTime: number,
	queue: { SpawnJob },
	running: boolean,
	timer: MatchTimer,
}

local _waveTimerUpdatedRemote: RemoteEvent
local _battleKillsUpdatedRemote: RemoteEvent
local _spawnPointsByName: { [string]: BasePart? } = {}
local _matchState: MatchState? = nil
local _random = Random.new()
local _tiers: { FluxTier } = FluxConfig.TIERS

local function validatePositiveInteger(value: number, label: string)
	assert(value > 0 and value == math.floor(value), "[WaveService] " .. label .. " must be a positive integer.")
end

local function validateCueEntry(cueEntry: CueEntry | WeightedCueEntry, context: string)
	assert(type(cueEntry.zombieType) == "string" and cueEntry.zombieType ~= "",
		"[WaveService] " .. context .. " has an invalid zombieType.")
	assert(ZombieConfig.ZOMBIE_TYPES[cueEntry.zombieType] ~= nil,
		"[WaveService] " .. context .. " references unknown zombie type '" .. cueEntry.zombieType .. "'.")
	assert(type(cueEntry.spawnPointName) == "string" and cueEntry.spawnPointName ~= "",
		"[WaveService] " .. context .. " has an invalid spawnPointName.")
	validatePositiveInteger(cueEntry.amount, context .. ".amount")
end

local function validateConfiguration()
	assert(FluxConfig.BATTLE_DURATION > 0, "[WaveService] BATTLE_DURATION must be positive.")
	assert(FluxConfig.SCHEDULER_INTERVAL > 0, "[WaveService] SCHEDULER_INTERVAL must be positive.")
	assert(FluxConfig.SPAWN_INTERVAL >= 0, "[WaveService] SPAWN_INTERVAL cannot be negative.")
	assert(#_tiers > 0, "[WaveService] Flux configuration must define at least one tier.")

	local previousStartTime = -1
	for tierIndex, tier in ipairs(_tiers) do
		assert(tier.startTimeSeconds >= 0 and tier.startTimeSeconds == math.floor(tier.startTimeSeconds),
			string.format("[WaveService] Tier %d startTimeSeconds must be a non-negative integer.", tierIndex))
		assert(tier.startTimeSeconds > previousStartTime,
			string.format("[WaveService] Tier %d must begin after the preceding tier.", tierIndex))
		validatePositiveInteger(tier.maxAlive, string.format("Tier %d maxAlive", tierIndex))
		assert(#tier.randomCue > 0, string.format("[WaveService] Tier %d must define randomCue entries.", tierIndex))

		for entryIndex, cueEntry in ipairs(tier.entryCue) do
			validateCueEntry(cueEntry, string.format("Tier %d entryCue %d", tierIndex, entryIndex))
		end
		for entryIndex, cueEntry in ipairs(tier.randomCue) do
			validateCueEntry(cueEntry, string.format("Tier %d randomCue %d", tierIndex, entryIndex))
			validatePositiveInteger(cueEntry.weight, string.format("Tier %d randomCue %d weight", tierIndex, entryIndex))
		end

		previousStartTime = tier.startTimeSeconds
	end

	assert(_tiers[1].startTimeSeconds == 0, "[WaveService] The first flux tier must begin at 0 seconds.")
end

local function cacheSpawnPoint(spawnPointName: string, context: string)
	if _spawnPointsByName[spawnPointName] ~= nil then
		return
	end

	local matches: { BasePart } = {}
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == spawnPointName then
			assert(descendant:IsA("BasePart"),
				"[WaveService] " .. context .. " spawn location '" .. spawnPointName .. "' must be a BasePart.")
			table.insert(matches, descendant)
		end
	end
	assert(#matches == 1,
		"[WaveService] " .. context .. " requires exactly one BasePart named '" .. spawnPointName
			.. "', found " .. #matches .. ".")
	_spawnPointsByName[spawnPointName] = matches[1]
end

local function cacheConfiguredSpawnPoints()
	for tierIndex, tier in ipairs(_tiers) do
		for entryIndex, cueEntry in ipairs(tier.entryCue) do
			cacheSpawnPoint(cueEntry.spawnPointName, string.format("Tier %d entryCue %d", tierIndex, entryIndex))
		end
		for entryIndex, cueEntry in ipairs(tier.randomCue) do
			cacheSpawnPoint(cueEntry.spawnPointName, string.format("Tier %d randomCue %d", tierIndex, entryIndex))
		end
	end
end

local function initializeWaveService()
	_waveTimerUpdatedRemote = Framework.CreateRemote("WaveTimerUpdated")
	_battleKillsUpdatedRemote = Framework.CreateRemote("BattleKillsUpdated")
	validateConfiguration()
	cacheConfiguredSpawnPoints()
end

local function startWaveService() end

local WaveService = Framework.CreateService({
	Name = TAG,
	Init = initializeWaveService,
	Start = startWaveService,
})

local function enqueueEntry(match: MatchState, cueEntry: CueEntry | WeightedCueEntry): { number }
	validateCueEntry(cueEntry, "Cue entry")
	assert(_spawnPointsByName[cueEntry.spawnPointName] ~= nil,
		"[WaveService] Cue entry references unconfigured spawn location '" .. cueEntry.spawnPointName .. "'.")

	local jobIds: { number } = table.create(cueEntry.amount)
	for _ = 1, cueEntry.amount do
		match.nextJobId += 1
		local jobId = match.nextJobId
		table.insert(match.queue, {
			id = jobId,
			zombieType = cueEntry.zombieType,
			spawnPointName = cueEntry.spawnPointName,
		})
		table.insert(jobIds, jobId)
	end
	return jobIds
end

local function enqueueTierEntryCue(match: MatchState, tier: FluxTier)
	for _, cueEntry in ipairs(tier.entryCue) do
		enqueueEntry(match, cueEntry)
	end
end

local function chooseRandomCueEntry(tier: FluxTier): CueEntry
	local totalWeight = 0
	for _, cueEntry in ipairs(tier.randomCue) do
		totalWeight += cueEntry.weight
	end

	local roll = _random:NextInteger(1, totalWeight)
	local cumulativeWeight = 0
	for _, cueEntry in ipairs(tier.randomCue) do
		cumulativeWeight += cueEntry.weight
		if roll <= cumulativeWeight then
			return cueEntry
		end
	end

	error("[WaveService] Random cue selection failed after configuration validation.")
end

local function getTierIndex(elapsedSeconds: number): number
	local activeTierIndex = 1
	for tierIndex, tier in ipairs(_tiers) do
		if tier.startTimeSeconds > elapsedSeconds then
			break
		end
		activeTierIndex = tierIndex
	end
	return activeTierIndex
end

local function isParticipantAlive(match: MatchState, player: Player): boolean
	local humanoid = match.participantHumanoids[player]
	return player.Parent ~= nil and humanoid.Parent ~= nil and humanoid.Health > 0
end

local function hasLivingParticipant(match: MatchState): boolean
	for _, player in ipairs(match.participants) do
		if isParticipantAlive(match, player) then
			return true
		end
	end
	return false
end

local function getNextLivingParticipant(match: MatchState): Player
	local participantCount = #match.participants
	assert(participantCount > 0, "[WaveService] Match state has no participants.")

	for _ = 1, participantCount do
		local player = match.participants[match.nextOwnerIndex]
		match.nextOwnerIndex = match.nextOwnerIndex % participantCount + 1
		if isParticipantAlive(match, player) then
			return player
		end
	end

	error("[WaveService] Cannot select a spawn owner without a living participant.")
end

local function setFluxTierForParticipants(match: MatchState, tierIndex: number)
	for _, player in ipairs(match.participants) do
		if player.Parent then
			player:SetAttribute("CurrentFluxTier", tierIndex)
		end
	end
end

local function clearFluxTierForParticipants(match: MatchState)
	for _, player in ipairs(match.participants) do
		if player.Parent then
			player:SetAttribute("CurrentFluxTier", nil)
		end
	end
end

local function runMatchTimer(timer: MatchTimer)
	local deadline = os.clock() + FluxConfig.BATTLE_DURATION
	local lastRemaining = -1

	while not timer.stopped do
		local remaining = math.max(0, math.ceil(deadline - os.clock()))
		if remaining ~= lastRemaining then
			Logger.fireAllClients(_waveTimerUpdatedRemote, remaining)
			lastRemaining = remaining
		end
		if remaining == 0 then
			timer.expired = true
			return
		end
		task.wait(0.5)
	end
end

local function spawnQueuedZombie(match: MatchState)
	local job = table.remove(match.queue, 1)
	assert(job ~= nil, "[WaveService] Cannot dispatch a zombie from an empty cue.")
	local spawnPoint = _spawnPointsByName[job.spawnPointName]
	assert(spawnPoint ~= nil, "[WaveService] Spawn job references an unresolved spawn location.")
	local owner = getNextLivingParticipant(match)

	match.aliveCount += 1
	local didHandleDeath = false
	local function onZombieDied(deathPosition: Vector3?)
		if didHandleDeath or not match.running then
			return
		end
		didHandleDeath = true
		assert(match.aliveCount > 0, "[WaveService] Zombie death received with no alive zombies tracked.")
		match.aliveCount -= 1
		if not deathPosition then
			return
		end
		match.kills += 1
		Logger.fireAllClients(_battleKillsUpdatedRemote, match.kills)
		if isParticipantAlive(match, owner) then
			PowerupService.onZombieKilled(owner, deathPosition)
		end
	end

	ZombieService.spawn(owner, onZombieDied, spawnPoint.Position, job.zombieType)
end

local function runFluxScheduler(match: MatchState)
	local startedAt = os.clock()
	match.activeTierIndex = getTierIndex(0)
	match.highestTierReached = match.activeTierIndex
	enqueueTierEntryCue(match, _tiers[match.activeTierIndex])
	setFluxTierForParticipants(match, match.activeTierIndex)

	while match.running and not match.timer.expired and hasLivingParticipant(match) do
		local elapsedSeconds = os.clock() - startedAt
		local tierIndex = getTierIndex(elapsedSeconds)
		if tierIndex ~= match.activeTierIndex then
			match.activeTierIndex = tierIndex
			match.highestTierReached = tierIndex
			setFluxTierForParticipants(match, tierIndex)
			enqueueTierEntryCue(match, _tiers[tierIndex])
			Logger.info(TAG, "Match entered flux tier %d.", tierIndex)
		end

		local tier = _tiers[match.activeTierIndex]
		if match.aliveCount < tier.maxAlive and os.clock() - match.lastSpawnTime >= FluxConfig.SPAWN_INTERVAL then
			if #match.queue == 0 then
				enqueueEntry(match, chooseRandomCueEntry(tier))
			end
			spawnQueuedZombie(match)
			match.lastSpawnTime = os.clock()
		end

		task.wait(FluxConfig.SCHEDULER_INTERVAL)
	end
end

local function beginParticipantRuns(match: MatchState)
	for _, player in ipairs(match.participants) do
		EconomyService.beginRun(player)
		PowerupService.beginBattle(player)
		Logger.fireClient(_battleKillsUpdatedRemote, player, match.kills)
	end
end

local function endParticipantRuns(match: MatchState)
	for _, player in ipairs(match.participants) do
		ZombieService.cleanupForPlayer(player.Name)
		PowerupService.endBattle(player)
	end
end

function WaveService.addZombieToCue(cueEntry: CueEntry): { number }
	local match = _matchState
	assert(match ~= nil and match.running, "[WaveService] Cannot add a zombie to the cue without an active match.")
	return enqueueEntry(match, cueEntry)
end

function WaveService.removeZombieFromCue(jobId: number): boolean
	local match = _matchState
	assert(match ~= nil and match.running, "[WaveService] Cannot remove a zombie from the cue without an active match.")
	validatePositiveInteger(jobId, "Cue job id")

	for queueIndex, job in ipairs(match.queue) do
		if job.id == jobId then
			table.remove(match.queue, queueIndex)
			return true
		end
	end
	return false
end

function WaveService.startMatch(participants: { Player }): number
	assert(_matchState == nil, "[WaveService] A flux match is already active.")
	assert(#participants > 0, "[WaveService] Cannot start a flux match without participants.")

	local participantHumanoids: { [Player]: Humanoid } = {}
	for _, player in ipairs(participants) do
		assert(player.Parent ~= nil, "[WaveService] Cannot start a flux match for a disconnected player: " .. player.Name)
		participantHumanoids[player] = CharacterService.waitFor(player).humanoid
	end

	local match: MatchState = {
		participants = participants,
		participantHumanoids = participantHumanoids,
		kills = 0,
		aliveCount = 0,
		activeTierIndex = 0,
		highestTierReached = 0,
		nextJobId = 0,
		nextOwnerIndex = 1,
		lastSpawnTime = -math.huge,
		queue = {},
		running = true,
		timer = {
			expired = false,
			stopped = false,
		},
	}
	_matchState = match
	Logger.info(TAG, "Starting shared flux match for %d participants.", #participants)
	beginParticipantRuns(match)
	task.spawn(runMatchTimer, match.timer)

	runFluxScheduler(match)

	match.running = false
	match.timer.stopped = true
	endParticipantRuns(match)
	clearFluxTierForParticipants(match)
	_matchState = nil
	Logger.info(TAG, "Final shared flux tier: %d.", match.highestTierReached)
	return match.highestTierReached
end

return WaveService