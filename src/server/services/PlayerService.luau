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
			PlayerService._spawnAtLobby(character)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		-- Release the active slot immediately so no ghost entry persists.
		_activePlayers[player] = nil
	end)

	-- Handle players who joined before this service started (Studio edge-case).
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(character: Model)
			PlayerService._spawnAtLobby(character)
		end)
		if player.Character then
			PlayerService._spawnAtLobby(player.Character)
		end
	end

	Logger.info(TAG, "Player lifecycle listeners connected.")
end

-- ── Private helpers ───────────────────────────────────────────────────────────

function PlayerService._spawnAtLobby(character: Model)
	-- Wait for HumanoidRootPart: CharacterAdded fires before all parts are ready.
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if not hrp then return end
	-- Yield one frame so Roblox's SpawnLocation teleport runs first; then we override.
	task.wait()
	local lobby = workspace:FindFirstChild(Config.LOBBY_NAME)
	if not lobby or not lobby:IsA("Model") then return end
	local spawnPart = lobby:FindFirstChild("Spawn_In", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		character:PivotTo((spawnPart :: BasePart).CFrame * CFrame.new(0, 5, 0))
	else
		character:PivotTo((lobby :: Model):GetPivot() * CFrame.new(0, 5, 0))
	end
end

local function isEligibleToPlay(player: Player): boolean
	if _activePlayers[player] then return false end
	local character = player.Character
	local humanoid  = character and character:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
	return humanoid ~= nil and (humanoid :: Humanoid).Health > 0
end

function PlayerService._onRequestPlay(player: Player)
	Logger.verbose(TAG, "RequestPlay from %s — currently active: %s",
		player.Name, tostring(_activePlayers[player] ~= nil))

	if not isEligibleToPlay(player) then
		Logger.info(TAG, "RequestPlay rejected for %s (already active or dead).", player.Name)
		return
	end

	_activePlayers[player] = true

	task.spawn(function()
		-- startBattle yields until the battle ends.
		local waveReached = WaveService.startBattle(player)
		Logger.info(TAG, "%s finished on wave %d.", player.Name, waveReached)

		-- Save regardless of how the battle ended (death, disconnect, etc.).
		DataService.saveStats(player, waveReached)

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
