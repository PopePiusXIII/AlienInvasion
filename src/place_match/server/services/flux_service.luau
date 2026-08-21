--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)
local FluxConfig = require(replicated_storage.match.shared.configs.flux_config)
local ZombieConfig = require(replicated_storage.match.shared.configs.zombie_config)
local WaveTypes = require(replicated_storage.match.shared.types.wave_types)
local ZombieService = require(server_script_service.match.services.zombie_service)
local PowerupService = require(server_script_service.match.services.powerup_service)

local TAG = "FluxService"

type CueEntry = WaveTypes.CueEntry
type WeightedCueEntry = WaveTypes.WeightedCueEntry
type FluxTier = WaveTypes.FluxTier
type MatchTimer = WaveTypes.MatchTimer
type MatchState = WaveTypes.MatchState
type FluxLevel = FluxConfig.Level

local _waveTimerUpdatedRemote: RemoteEvent
local _battleKillsUpdatedRemote: RemoteEvent
local _spawnPointsByName: { [string]: BasePart? } = {}
local _activeMatch: MatchState? = nil
local _random = Random.new()

local function validatePositiveInteger(value: number, label: string)
	assert(value > 0 and value == math.floor(value), "[FluxService] " .. label .. " must be a positive integer.")
end

local function validateCueEntry(cueEntry: CueEntry | WeightedCueEntry, context: string)
	assert(type(cueEntry.zombieType) == "string" and cueEntry.zombieType ~= "",
		"[FluxService] " .. context .. " has an invalid zombieType.")
	assert(ZombieConfig.ZOMBIE_TYPES[cueEntry.zombieType] ~= nil,
		"[FluxService] " .. context .. " references unknown zombie type '" .. cueEntry.zombieType .. "'.")
	assert(type(cueEntry.spawnPointName) == "string" and cueEntry.spawnPointName ~= "",
		"[FluxService] " .. context .. " has an invalid spawnPointName.")
	validatePositiveInteger(cueEntry.amount, context .. ".amount")
end

local function validateTiers(tiers: { FluxTier }, context: string)
	assert(#tiers > 0, "[FluxService] " .. context .. " must define at least one tier.")

	local previousStartTime = -1
	for tierIndex, tier in ipairs(tiers) do
		assert(tier.startTimeSeconds >= 0 and tier.startTimeSeconds == math.floor(tier.startTimeSeconds),
			string.format("[FluxService] %s tier %d startTimeSeconds must be a non-negative integer.", context, tierIndex))
		assert(tier.startTimeSeconds > previousStartTime,
			string.format("[FluxService] %s tier %d must begin after the preceding tier.", context, tierIndex))
		validatePositiveInteger(tier.maxAlive, string.format("%s tier %d maxAlive", context, tierIndex))
		assert(#tier.randomCue > 0, string.format("[FluxService] %s tier %d must define randomCue entries.", context, tierIndex))

		for entryIndex, cueEntry in ipairs(tier.entryCue) do
			validateCueEntry(cueEntry, string.format("%s tier %d entryCue %d", context, tierIndex, entryIndex))
		end
		for entryIndex, cueEntry in ipairs(tier.randomCue) do
			validateCueEntry(cueEntry, string.format("%s tier %d randomCue %d", context, tierIndex, entryIndex))
			validatePositiveInteger(cueEntry.weight, string.format("%s tier %d randomCue %d weight", context, tierIndex, entryIndex))
		end

		previousStartTime = tier.startTimeSeconds
	end

	assert(tiers[1].startTimeSeconds == 0, "[FluxService] " .. context .. " must begin at 0 seconds.")
end

local function validateConfiguration()
	assert(FluxConfig.BATTLE_DURATION > 0, "[FluxService] BATTLE_DURATION must be positive.")
	assert(FluxConfig.SCHEDULER_INTERVAL > 0, "[FluxService] SCHEDULER_INTERVAL must be positive.")
	assert(FluxConfig.ZOMBIE_SPAWN_INTERVAL >= 0, "[FluxService] ZOMBIE_SPAWN_INTERVAL cannot be negative.")
	assert(#FluxConfig.LEVEL_ORDER > 0, "[FluxService] Flux configuration must define at least one level.")

	for levelIndex, levelId in ipairs(FluxConfig.LEVEL_ORDER) do
		local level = FluxConfig.LEVELS[levelId]
		assert(level ~= nil, string.format("[FluxService] LEVEL_ORDER entry %d references unknown level '%s'.", levelIndex, levelId))
		assert(level.id == levelId, string.format("[FluxService] Level '%s' must declare the matching id.", levelId))
		validateTiers(level.tiers, "Level '" .. levelId .. "'")
	end
end

local function cacheSpawnPoint(spawnPointName: string, context: string)
	if _spawnPointsByName[spawnPointName] ~= nil then
		return
	end

	local matches: { BasePart } = {}
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == spawnPointName then
			assert(descendant:IsA("BasePart"),
				"[FluxService] " .. context .. " spawn location '" .. spawnPointName .. "' must be a BasePart.")
			table.insert(matches, descendant)
		end
	end
	assert(#matches == 1,
		"[FluxService] " .. context .. " requires exactly one BasePart named '" .. spawnPointName
			.. "', found " .. #matches .. ".")
	_spawnPointsByName[spawnPointName] = matches[1]
end

local function cacheConfiguredSpawnPoints()
	for _, levelId in ipairs(FluxConfig.LEVEL_ORDER) do
		local level = FluxConfig.LEVELS[levelId]
		for tierIndex, tier in ipairs(level.tiers) do
			for entryIndex, cueEntry in ipairs(tier.entryCue) do
				cacheSpawnPoint(cueEntry.spawnPointName, string.format("Level '%s' tier %d entryCue %d", levelId, tierIndex, entryIndex))
			end
			for entryIndex, cueEntry in ipairs(tier.randomCue) do
				cacheSpawnPoint(cueEntry.spawnPointName, string.format("Level '%s' tier %d randomCue %d", levelId, tierIndex, entryIndex))
			end
		end
	end
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
	assert(participantCount > 0, "[FluxService] Match state has no participants.")

	for _ = 1, participantCount do
		local player = match.participants[match.nextOwnerIndex]
		match.nextOwnerIndex = match.nextOwnerIndex % participantCount + 1
		if isParticipantAlive(match, player) then
			return player
		end
	end

	error("[FluxService] Cannot select a spawn owner without a living participant.")
end

local function enqueueEntry(match: MatchState, cueEntry: CueEntry | WeightedCueEntry)
	for _ = 1, cueEntry.amount do
		table.insert(match.queue, {
			zombieType = cueEntry.zombieType,
			spawnPointName = cueEntry.spawnPointName,
		})
	end
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

	error("[FluxService] Random cue selection failed after configuration validation.")
end

local function getTierIndex(tiers: { FluxTier }, elapsedSeconds: number): number
	local activeTierIndex = 1
	for tierIndex, tier in ipairs(tiers) do
		if tier.startTimeSeconds > elapsedSeconds then
			break
		end
		activeTierIndex = tierIndex
	end
	return activeTierIndex
end

local function runLevelTimer(timer: MatchTimer)
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
	assert(job ~= nil, "[FluxService] Cannot dispatch a zombie from an empty cue.")
	local spawnPoint = _spawnPointsByName[job.spawnPointName]
	if spawnPoint == nil or spawnPoint.Parent == nil then
		_spawnPointsByName[job.spawnPointName] = nil
		cacheSpawnPoint(job.spawnPointName, "Spawn job")
		spawnPoint = _spawnPointsByName[job.spawnPointName]
	end
	assert(spawnPoint ~= nil, "[FluxService] Spawn job references an unresolved spawn location.")
	local owner = getNextLivingParticipant(match)

	match.aliveCount += 1
	local didHandleDeath = false
	local function onZombieDied(deathPosition: Vector3?)
		if didHandleDeath or not match.running then
			return
		end
		didHandleDeath = true
		assert(match.aliveCount > 0, "[FluxService] Zombie death received with no alive zombies tracked.")
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

local function runFluxScheduler(match: MatchState, tiers: { FluxTier }): boolean
	local startedAt = os.clock()
	match.activeTierIndex = getTierIndex(tiers, 0)
	match.highestTierReached = match.activeTierIndex
	enqueueTierEntryCue(match, tiers[match.activeTierIndex])

	while match.running and not match.timer.expired and hasLivingParticipant(match) do
		local elapsedSeconds = os.clock() - startedAt
		local tierIndex = getTierIndex(tiers, elapsedSeconds)
		if tierIndex ~= match.activeTierIndex then
			match.activeTierIndex = tierIndex
			match.highestTierReached = tierIndex
			enqueueTierEntryCue(match, tiers[tierIndex])
			Logger.info(TAG, "Level entered flux tier %d.", tierIndex)
		end

		local tier = tiers[match.activeTierIndex]
		if match.aliveCount < tier.maxAlive and os.clock() - match.lastSpawnTime >= FluxConfig.ZOMBIE_SPAWN_INTERVAL then
			if #match.queue == 0 then
				enqueueEntry(match, chooseRandomCueEntry(tier))
			end
			spawnQueuedZombie(match)
			match.lastSpawnTime = os.clock()
		end

		task.wait(FluxConfig.SCHEDULER_INTERVAL)
	end

	if not match.running or not match.timer.expired then
		return false
	end

	table.clear(match.queue)
	while match.running and match.aliveCount > 0 and hasLivingParticipant(match) do
		task.wait(FluxConfig.SCHEDULER_INTERVAL)
	end

	return match.running and match.aliveCount == 0 and hasLivingParticipant(match)
end

local function initializeFluxService()
	_waveTimerUpdatedRemote = Framework.CreateRemote("WaveTimerUpdated")
	_battleKillsUpdatedRemote = Framework.CreateRemote("BattleKillsUpdated")
	validateConfiguration()
	cacheConfiguredSpawnPoints()
end

local function startFluxService() end

local FluxService = Framework.CreateService({
	Name = TAG,
	Init = initializeFluxService,
	Start = startFluxService,
})

function FluxService.getActiveFluxTier(): number
	local match = _activeMatch
	assert(match ~= nil and match.running, "[FluxService] Cannot get the active flux tier without an active level.")
	validatePositiveInteger(match.activeTierIndex, "Active flux tier")
	return match.activeTierIndex
end

function FluxService.runLevel(match: MatchState, level: FluxLevel): boolean
	assert(_activeMatch == nil, "[FluxService] A flux level is already active.")
	assert(match.running, "[FluxService] Cannot run a level for an inactive match.")
	assert(match.aliveCount == 0 and #match.queue == 0, "[FluxService] Cannot begin a level with active zombies or queued spawns.")

	_activeMatch = match
	match.timer = {
		expired = false,
		stopped = false,
	}
	match.lastSpawnTime = -math.huge
	task.spawn(runLevelTimer, match.timer)

	local completedLevel = runFluxScheduler(match, level.tiers)
	match.timer.stopped = true
	_activeMatch = nil
	return completedLevel
end

return FluxService