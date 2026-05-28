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

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework    = require(ReplicatedStorage.Shared.Framework)
local Logger       = require(ReplicatedStorage.Shared.Logger)
local Config       = require(ReplicatedStorage.Shared.Config)
local RemoteNames  = require(ReplicatedStorage.Shared.RemoteNames)
local ZombieService = require(script.Parent.ZombieService)
local ClerkInteractionModule = require(script.Parent.modules.wave.ClerkInteractionModule)
local LoadoutGrantModule = require(script.Parent.modules.wave.LoadoutGrantModule)

local TAG = "WaveService"

local WaveService = Framework.CreateService({ Name = TAG })

local _waveAnnounceRemote: RemoteEvent
local _waveClearRemote:    RemoteEvent
local _nextMapSlot:        number = 0

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function WaveService:Init()
	-- Create remotes during Init so they exist in RS.Remotes before any client joins.
	_waveAnnounceRemote = Framework.CreateRemote(RemoteNames.WAVE_ANNOUNCE)
	_waveClearRemote    = Framework.CreateRemote(RemoteNames.WAVE_CLEAR)
	Logger.info(TAG, "Remotes created: %s, %s", RemoteNames.WAVE_ANNOUNCE, RemoteNames.WAVE_CLEAR)
end

-- ── Private helpers ───────────────────────────────────────────────────────────

local function cloneMap(player: Player): Model?
	local template = ServerStorage:FindFirstChild(Config.MAP_NAME)
	if not template or not template:IsA("Model") then
		Logger.warn(TAG, "Map template '%s' not found in ServerStorage.", Config.MAP_NAME)
		return nil
	end
	local slot     = _nextMapSlot
	_nextMapSlot  += 1
	local map: Model = (template :: Model):Clone() :: Model
	map.Name   = Config.MAP_NAME .. "_" .. player.Name
	-- Space maps 4000 studs apart on the X axis to avoid overlap.
	map:PivotTo(CFrame.new(slot * 4000, 0, 5000))
	map.Parent = workspace
	return map
end

local function teleportToMap(player: Player, map: Model)
	local character = player.Character
	if not character then return end
	local spawnPart = map:FindFirstChild("Spawn_In", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		character:PivotTo((spawnPart :: BasePart).CFrame * CFrame.new(0, 5, 0))
	else
		character:PivotTo(map:GetPivot() * CFrame.new(0, 5, 0))
	end
end

local function giveGuns(player: Player)
	local desiredGunNames: { string } = { "M82", "Deagle", "M60", "M240B" }
	LoadoutGrantModule.grant(player, desiredGunNames, function(message: string, ...: any)
		Logger.warn(TAG, message, ...)
	end)
end

local function findZombieSpawnPosition(map: Model): Vector3
	local spawnPart = map:FindFirstChild("Spawn_Mob", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		return (spawnPart :: BasePart).Position
	end
	return map:GetPivot().Position
end

local function getBattleHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
end

-- Runs one full wave: spawns all zombies, waits for all to die (or player death).
local function runWave(player: Player, waveNumber: number, spawnPos: Vector3, humanoid: Humanoid)
	Logger.info(TAG, "Wave %d — %s (%d zombies).", waveNumber, player.Name, waveNumber)

	-- All network sends go through Logger middleware for payload tracing.
	Logger.fireClient(_waveAnnounceRemote, player, waveNumber)

	local remaining = waveNumber
	local function onZombieDied() remaining -= 1 end

	for i = 1, waveNumber do
		if not player.Parent or humanoid.Health <= 0 then break end
		ZombieService.spawn(player, onZombieDied, spawnPos)
		if i < waveNumber then
			task.wait(Config.WAVE_SPAWN_INTERVAL)
		end
	end

	-- Polling loop: yield until all zombies are dead or the run is over.
	while remaining > 0 and player.Parent and humanoid.Health > 0 do
		task.wait(0.5)
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Run the full solo battle for one player. YIELDS until they die or disconnect.
--- Returns the last wave number reached (0 if the map or humanoid was unavailable).
function WaveService.startBattle(player: Player): number
	local map = cloneMap(player)
	if not map then return 0 end

	local humanoid = getBattleHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		map:Destroy()
		return 0
	end

	teleportToMap(player, map)
	local attached = ClerkInteractionModule.attach(map, player, function()
		giveGuns(player)
	end)
	if not attached then
		Logger.warn(TAG, "shopClerk part not found in map '%s'.", map.Name)
	end

	local spawnPos   = findZombieSpawnPosition(map)
	local waveNumber = Config.STARTING_WAVE

	-- The humanoid reference is captured once. Even if the character respawns,
	-- this humanoid's Health drops to 0 on death, so the loop detects it correctly.
	while player.Parent and humanoid.Health > 0 do
		runWave(player, waveNumber, spawnPos, humanoid)

		if humanoid.Health <= 0 then
			Logger.info(TAG, "%s died on wave %d.", player.Name, waveNumber)
			ZombieService.cleanupForPlayer(player.Name)
			break
		end

		Logger.info(TAG, "Wave %d cleared for %s. Next in %ds.",
			waveNumber, player.Name, Config.WAVE_BETWEEN_DELAY)
		Logger.fireClient(_waveClearRemote, player)
		task.wait(Config.WAVE_BETWEEN_DELAY)
		waveNumber += 1
	end

	map:Destroy()
	Logger.info(TAG, "Map cleaned up for %s. Final wave: %d.", player.Name, waveNumber)
	return waveNumber
end

return WaveService
