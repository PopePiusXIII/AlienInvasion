--!strict

local Players = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local CharacterLevelConfig = require(replicated_storage.match.shared.configs.character_level_config)
local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)
local RemoteNames = require(replicated_storage.match.shared.remote_names)
local EconomyService = require(server_script_service.match.services.economy_service)
local RngService = require(server_script_service.match.services.rng_service)

local TAG = "CharacterLevelService"
local CharacterLevelService = {}
CharacterLevelService.Name = TAG

export type LevelState = {
	level: number,
	experience: number,
}

local _levelStateByPlayer: { [Player]: LevelState } = {}
local _levelUp = Instance.new("BindableEvent")
local _experienceUpdatedRemote: RemoteEvent

local function calculateXpRequired(level: number): number
	local normalizedLevel = math.max(1, math.floor(level))
	local required = CharacterLevelConfig.XP_REQUIRED_A * normalizedLevel ^ 2
		+ CharacterLevelConfig.XP_REQUIRED_B * normalizedLevel
		+ CharacterLevelConfig.XP_REQUIRED_C
	return math.max(1, math.floor(required))
end

local function publishExperience(player: Player, state: LevelState)
	_experienceUpdatedRemote:FireClient(player, state.level, state.experience, calculateXpRequired(state.level))
end

local function getLevelState(player: Player): LevelState
	local state = _levelStateByPlayer[player]
	if state then
		return state
	end

	local newState: LevelState = {
		level = 1,
		experience = 0,
	}
	_levelStateByPlayer[player] = newState
	publishExperience(player, newState)
	return newState
end

---------------------------- API ------------------------------------------------

function CharacterLevelService.getXpRequired(level: number): number
	return calculateXpRequired(level)
end

function CharacterLevelService.getState(player: Player): LevelState
	return getLevelState(player)
end

function CharacterLevelService.onLevelUp(callback: (Player, number, number, number) -> ()): RBXScriptConnection
	return _levelUp.Event:Connect(callback)
end

function CharacterLevelService.addExperience(player: Player, amount: number)
	local earnedExperience = math.max(0, math.floor(amount))
	if earnedExperience == 0 then
		return
	end

	local state = getLevelState(player)
	state.experience += earnedExperience

	while state.experience >= calculateXpRequired(state.level) do
		state.experience -= calculateXpRequired(state.level)
		state.level += 1
		local nextLevelRequirement = calculateXpRequired(state.level)
		_levelUp:Fire(player, state.level, state.experience, nextLevelRequirement)
		Logger.info(TAG, "%s reached level %d.", player.Name, state.level)
	end

	publishExperience(player, state)
end

---------------------------- END-API ------------------------------------------------


function CharacterLevelService:Init()
	_experienceUpdatedRemote = Framework.CreateRemote(RemoteNames.EXPERIENCE_UPDATED)
	for _, player in ipairs(Players:GetPlayers()) do
		getLevelState(player)
	end
	EconomyService.onBoltCollected(function(player: Player, _: string, amount: number)
		CharacterLevelService.addExperience(player, amount)
	end)
	CharacterLevelService.onLevelUp(function(player: Player)
		RngService.activate(player)
	end)
end

function CharacterLevelService:Start()
	Players.PlayerAdded:Connect(getLevelState)
	Players.PlayerRemoving:Connect(function(player: Player)
		_levelStateByPlayer[player] = nil
	end)
end

CharacterLevelService = Framework.CreateService(CharacterLevelService)

return CharacterLevelService
