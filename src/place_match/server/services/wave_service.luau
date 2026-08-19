--!strict
--------------------------------------------------------------------------------
-- WaveService.luau  (src/server/services)
-- Owns each player's timed zombie flux lifecycle and spawn cue.
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

type BattleTimer = {
	expired: boolean,
	stopped: boolean,
}

type SpawnJob = {
	id: number,
	zombieType: string,
	spawnPointName: string,
}

type BattleState = {
	kills: number,
	aliveCount: number,
	activeTierIndex: number,
	highestTierReached: number,
	nextJobId: number,
	lastSpawnTime: number,
	queue: { SpawnJob },
	running: boolean,
	timer: BattleTimer,
}

local _waveTimerUpdatedRemote: RemoteEvent
local _battleKillsUpdatedRemote: RemoteEvent
local _spawnPointsByName: { [string]: BasePart? } = {}
local _battlesByPlayer: { [Player]: BattleState } = {}
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

local function enqueueEntry(battle: BattleState, cueEntry: CueEntry | WeightedCueEntry): { number }
	validateCueEntry(cueEntry, "Cue entry")
	assert(_spawnPointsByName[cueEntry.spawnPointName] ~= nil,
		"[WaveService] Cue entry references unconfigured spawn location '" .. cueEntry.spawnPointName .. "'.")

	local jobIds: { number } = table.create(cueEntry.amount)
	for _ = 1, cueEntry.amount do
		battle.nextJobId += 1
		local jobId = battle.nextJobId
		table.insert(battle.queue, {
			id = jobId,
			zombieType = cueEntry.zombieType,
			spawnPointName = cueEntry.spawnPointName,
		})
		table.insert(jobIds, jobId)
	end
	return jobIds
end

local function enqueueTierEntryCue(battle: BattleState, tier: FluxTier)
	for _, cueEntry in ipairs(tier.entryCue) do
		enqueueEntry(battle, cueEntry)
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

local function runBattleTimer(player: Player, timer: BattleTimer)
	local deadline = os.clock() + FluxConfig.BATTLE_DURATION
	local lastRemaining = -1

	while player.Parent and not timer.stopped do
		local remaining = math.max(0, math.ceil(deadline - os.clock()))
		if remaining ~= lastRemaining then
			Logger.fireClient(_waveTimerUpdatedRemote, player, remaining)
			lastRemaining = remaining
		end
		if remaining == 0 then
			timer.expired = true
			return
		end
		task.wait(0.5)
	end
end

local function spawnQueuedZombie(player: Player, battle: BattleState)
	local job = table.remove(battle.queue, 1)
	assert(job ~= nil, "[WaveService] Cannot dispatch a zombie from an empty cue.")
	local spawnPoint = _spawnPointsByName[job.spawnPointName]
	assert(spawnPoint ~= nil, "[WaveService] Spawn job references an unresolved spawn location.")

	battle.aliveCount += 1
	local didHandleDeath = false
	local function onZombieDied(deathPosition: Vector3?)
		if didHandleDeath or not battle.running then
			return
		end
		didHandleDeath = true
		assert(battle.aliveCount > 0, "[WaveService] Zombie death received with no alive zombies tracked.")
		battle.aliveCount -= 1
		if not deathPosition then
			return
		end
		battle.kills += 1
		Logger.fireClient(_battleKillsUpdatedRemote, player, battle.kills)
		PowerupService.onZombieKilled(player, deathPosition)
	end

	ZombieService.spawn(player, onZombieDied, spawnPoint.Position, job.zombieType)
end

local function runFluxScheduler(player: Player, humanoid: Humanoid, battle: BattleState)
	local startedAt = os.clock()
	battle.activeTierIndex = getTierIndex(0)
	battle.highestTierReached = battle.activeTierIndex
	enqueueTierEntryCue(battle, _tiers[battle.activeTierIndex])
	player:SetAttribute("CurrentFluxTier", battle.activeTierIndex)

	while battle.running and player.Parent and humanoid.Health > 0 and not battle.timer.expired do
		local elapsedSeconds = os.clock() - startedAt
		local tierIndex = getTierIndex(elapsedSeconds)
		if tierIndex ~= battle.activeTierIndex then
			battle.activeTierIndex = tierIndex
			battle.highestTierReached = tierIndex
			player:SetAttribute("CurrentFluxTier", tierIndex)
			enqueueTierEntryCue(battle, _tiers[tierIndex])
			Logger.info(TAG, "%s entered flux tier %d.", player.Name, tierIndex)
		end

		local tier = _tiers[battle.activeTierIndex]
		if battle.aliveCount < tier.maxAlive and os.clock() - battle.lastSpawnTime >= FluxConfig.SPAWN_INTERVAL then
			if #battle.queue == 0 then
				enqueueEntry(battle, chooseRandomCueEntry(tier))
			end
			spawnQueuedZombie(player, battle)
			battle.lastSpawnTime = os.clock()
		end

		task.wait(FluxConfig.SCHEDULER_INTERVAL)
	end
end

function WaveService.addZombieToCue(player: Player, cueEntry: CueEntry): { number }
	local battle = _battlesByPlayer[player]
	assert(battle ~= nil and battle.running,
		"[WaveService] Cannot add a zombie to the cue without an active battle for " .. player.Name .. ".")
	return enqueueEntry(battle, cueEntry)
end

function WaveService.removeZombieFromCue(player: Player, jobId: number): boolean
	local battle = _battlesByPlayer[player]
	assert(battle ~= nil and battle.running,
		"[WaveService] Cannot remove a zombie from the cue without an active battle for " .. player.Name .. ".")
	validatePositiveInteger(jobId, "Cue job id")

	for queueIndex, job in ipairs(battle.queue) do
		if job.id == jobId then
			table.remove(battle.queue, queueIndex)
			return true
		end
	end
	return false
end

function WaveService.startBattle(player: Player): number
	assert(_battlesByPlayer[player] == nil, "[WaveService] Battle already active for " .. player.Name .. ".")
	Logger.info(TAG, "startBattle: beginning flux run for %s.", player.Name)
	EconomyService.beginRun(player)

	local humanoid = CharacterService.waitFor(player).humanoid
	local battle: BattleState = {
		kills = 0,
		aliveCount = 0,
		activeTierIndex = 0,
		highestTierReached = 0,
		nextJobId = 0,
		lastSpawnTime = -math.huge,
		queue = {},
		running = true,
		timer = {
			expired = false,
			stopped = false,
		},
	}
	_battlesByPlayer[player] = battle
	PowerupService.beginBattle(player)
	Logger.fireClient(_battleKillsUpdatedRemote, player, battle.kills)
	task.spawn(runBattleTimer, player, battle.timer)

	runFluxScheduler(player, humanoid, battle)

	battle.running = false
	battle.timer.stopped = true
	ZombieService.cleanupForPlayer(player.Name)
	PowerupService.endBattle(player)
	_battlesByPlayer[player] = nil
	player:SetAttribute("CurrentFluxTier", nil)
	Logger.info(TAG, "Final flux tier: %d for %s.", battle.highestTierReached, player.Name)
	return battle.highestTierReached
end

return WaveService