--!strict
--------------------------------------------------------------------------------
-- WaveService.luau  (src/server/services)
-- Owns map cloning, gun distribution, and the wave progression loop.
-- Single Responsibility: wave lifecycle per player — no hit detection, no data.
--
-- Public API:
--   WaveService.startBattle(player) → number
--     Yields until the player dies or disconnects; returns final wave number.
--     Fires WaveAnnounce and WaveClear to the player via the Logger middleware.
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework    = require(replicated_storage.common.shared.framework)
local Logger       = require(replicated_storage.common.shared.logger)
local WaveConfig   = require(replicated_storage.match.shared.configs.wave_config)
local CharacterService = require(server_script_service.match.services.character_service)
local ZombieService = require(server_script_service.match.services.zombie_service)
local EconomyService = require(server_script_service.match.services.economy_service)
local PowerupService = require(server_script_service.match.services.powerup_service)

local TAG = "WaveService"

local _waveAnnounceRemote:       RemoteEvent
local _waveClearRemote:          RemoteEvent
local _waveTimerUpdatedRemote:   RemoteEvent
local _battleKillsUpdatedRemote: RemoteEvent
local _zombieSpawnPoints:        { BasePart } = {}
local _spawnRandom = Random.new()

type BattleTimer = {
	expired: boolean,
	stopped: boolean,
}

type BattleState = {
	kills: number,
	timer: BattleTimer,
}

local function isZombieSpawnPointName(name: string): boolean
	return name == "Spawn_Mob" or string.match(name, "^Spawn_Mob_[1-9]%d*$") ~= nil
end

local function getZombieSpawnPointOrder(spawnPoint: BasePart): number
	if spawnPoint.Name == "Spawn_Mob" then
		return 0
	end

	local suffix = string.match(spawnPoint.Name, "^Spawn_Mob_([1-9]%d*)$")
	assert(suffix, "[WaveService] Invalid zombie spawn point name: " .. spawnPoint:GetFullName())
	return tonumber(suffix) :: number
end

local function compareZombieSpawnPoints(left: BasePart, right: BasePart): boolean
	return getZombieSpawnPointOrder(left) < getZombieSpawnPointOrder(right)
end

local function cacheZombieSpawnPoints()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if isZombieSpawnPointName(descendant.Name) then
			assert(descendant:IsA("BasePart"),
				"[WaveService] Zombie spawn point must be a BasePart: " .. descendant:GetFullName())
			table.insert(_zombieSpawnPoints, descendant)
		end
	end

	assert(#_zombieSpawnPoints > 0,
		"[WaveService] No zombie spawn points found. Add a Workspace BasePart named Spawn_Mob or Spawn_Mob_<number>.")
	table.sort(_zombieSpawnPoints, compareZombieSpawnPoints)

	for _, spawnPoint in ipairs(_zombieSpawnPoints) do
		Logger.info(TAG, "Zombie spawn point cached: %s", spawnPoint:GetFullName())
	end
end

local function initializeWaveService()
	_waveAnnounceRemote = Framework.CreateRemote("WaveStarted")
	_waveClearRemote = Framework.CreateRemote("WaveCleared")
	_waveTimerUpdatedRemote = Framework.CreateRemote("WaveTimerUpdated")
	_battleKillsUpdatedRemote = Framework.CreateRemote("BattleKillsUpdated")
	cacheZombieSpawnPoints()
end

local function startWaveService() end

local WaveService = Framework.CreateService({
	Name = TAG,
	Init = initializeWaveService,
	Start = startWaveService,
})

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

-- ── Private helpers ───────────────────────────────────────────────────────────

local function selectZombieSpawnPosition(): Vector3
	local index = _spawnRandom:NextInteger(1, #_zombieSpawnPoints)
	return _zombieSpawnPoints[index].Position
end



local function pickZombieType(waveNumber: number): string
	if waveNumber >= 30 then
		local roll = math.random(4)
		if roll == 1 then return "Tank"
		elseif roll == 2 then return "Tank"
		else return "Normal" end
	elseif waveNumber >= 20 then
		local roll = math.random(3)
		if roll == 1 then return "Tank"
		elseif roll == 2 then return "Tank"
		else return "Normal" end
	elseif waveNumber >= 10 then
		local roll = math.random(3)
		if roll == 1 then return "Tank"
		elseif roll == 2 then return "Normal_Run"
		 else return "Normal" end
	else
		return "Normal"
	end
end

local function runBattleTimer(player: Player, timer: BattleTimer)
	local deadline = os.clock() + WaveConfig.BATTLE_DURATION
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

-- Runs one full wave: spawns all zombies, waits for all to die (or player death).
local function runWave(player: Player, waveNumber: number, humanoid: Humanoid, battle: BattleState)
	Logger.info(TAG, "Wave %d — %s (%d zombies).", waveNumber, player.Name, waveNumber)
	player:SetAttribute("CurrentWave", waveNumber)

	-- All network sends go through Logger middleware for payload tracing.
	Logger.fireClient(_waveAnnounceRemote, player, waveNumber)

	local remaining = 10 * waveNumber
	local function onZombieDied(deathPosition: Vector3?)
		remaining -= 1
		if not deathPosition then
			return
		end
		battle.kills += 1
		Logger.fireClient(_battleKillsUpdatedRemote, player, battle.kills)
		PowerupService.onZombieKilled(player, deathPosition)
	end

	local totalZombies = 10 * waveNumber
	for i = 1, totalZombies do
		if not player.Parent or humanoid.Health <= 0 or battle.timer.expired then break end
		local spawnPosition = selectZombieSpawnPosition()
		ZombieService.spawn(player, onZombieDied, spawnPosition, pickZombieType(waveNumber))
		if i < totalZombies then
			task.wait(WaveConfig.WAVE_SPAWN_INTERVAL)
		end
	end

	-- Polling loop: yield until all zombies are dead or the run is over.
	while remaining > 0 and player.Parent and humanoid.Health > 0 and not battle.timer.expired do
		task.wait(0.5)
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Run the full solo battle for one player. YIELDS until they die or disconnect.
--- Returns the last wave number reached (0 if the map or humanoid was unavailable).
function WaveService.startBattle(player: Player): number
	Logger.info(TAG, "startBattle: beginning run for %s.", player.Name)
	EconomyService.beginRun(player)
	player:SetAttribute("CurrentWave", WaveConfig.STARTING_WAVE)

	local humanoid = CharacterService.waitFor(player).humanoid
	Logger.info(TAG, "startBattle: character ready, starting waves (%s).", player.Name)

	local waveNumber = WaveConfig.STARTING_WAVE
	local battle: BattleState = {
		kills = 0,
		timer = {
			expired = false,
			stopped = false,
		},
	}
	PowerupService.beginBattle(player)
	Logger.fireClient(_battleKillsUpdatedRemote, player, battle.kills)
	task.spawn(runBattleTimer, player, battle.timer)

	-- The humanoid reference is captured once. Even if the character respawns,
	-- this humanoid's Health drops to 0 on death, so the loop detects it correctly.
	while player.Parent and humanoid.Health > 0 and not battle.timer.expired do
		runWave(player, waveNumber, humanoid, battle)

		if humanoid.Health <= 0 then
			Logger.info(TAG, "%s died on wave %d.", player.Name, waveNumber)
			ZombieService.cleanupForPlayer(player.Name)
			break
		end
		if battle.timer.expired then
			Logger.info(TAG, "%s ran out of time on wave %d.", player.Name, waveNumber)
			ZombieService.cleanupForPlayer(player.Name)
			break
		end

		Logger.info(TAG, "Wave %d cleared for %s. Next in %ds.",
			waveNumber, player.Name, WaveConfig.WAVE_BETWEEN_DELAY)
		Logger.fireClient(_waveClearRemote, player)
		task.wait(WaveConfig.WAVE_BETWEEN_DELAY)
		if battle.timer.expired then
			Logger.info(TAG, "%s ran out of time after wave %d.", player.Name, waveNumber)
			ZombieService.cleanupForPlayer(player.Name)
			break
		end
		waveNumber += 1
	end

	battle.timer.stopped = true
	PowerupService.endBattle(player)
	player:SetAttribute("CurrentWave", nil)
	Logger.info(TAG, "Final wave: %d for %s.", waveNumber, player.Name)
	return waveNumber
end

return WaveService
