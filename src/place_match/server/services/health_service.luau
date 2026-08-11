--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)
local PlayerConfig = require(replicated_storage.match.shared.configs.player_config)
local RemoteNames = require(replicated_storage.match.shared.remote_names)
local CharacterService = require(server_script_service.match.services.character_service)
local SkillService = require(server_script_service.match.services.skill_service)

local TAG = "HealthService"

local HealthService = {}
HealthService.Name = TAG

export type HealthTarget = Player | Humanoid

local _healthUpdatedRemote: RemoteEvent

local function resolveHumanoid(target: HealthTarget): Humanoid?
	if target:IsA("Humanoid") then
		return target
	end

	local context = CharacterService.get(target :: Player)
	if context then 
		return context.humanoid 
	else 
		return nil
	end
end

local function fireHealthUpdated(player: Player, humanoid: Humanoid)
	Logger.fireClient(_healthUpdatedRemote, player, humanoid.Health, humanoid.MaxHealth)
end

local function applyHealthModifier(player: Player, healthModifier: number)
	local context = CharacterService.get(player)
	if not context then return end

	local humanoid = context.humanoid
	local previousMaxHealth = math.max(1, humanoid.MaxHealth)
	local healthRatio = math.clamp(humanoid.Health / previousMaxHealth, 0, 1)
	local modifiedMaxHealth = math.max(1, math.round(PlayerConfig.PLAYER_MAX_HEALTH * healthModifier))

	humanoid.MaxHealth = modifiedMaxHealth
	humanoid.Health = modifiedMaxHealth * healthRatio

	fireHealthUpdated(player, humanoid)
end

local function onCharacterReady(player: Player)
	applyHealthModifier(player, SkillService.getPlayerModifiers(player).health)
end

function HealthService.is_alive(target: HealthTarget): boolean
	local humanoid = resolveHumanoid(target)
	return humanoid ~= nil and humanoid.Health > 0
end

function HealthService.take_damage(target: HealthTarget, amount: number): boolean
	local humanoid = resolveHumanoid(target)
	local damage = math.max(0, amount)
	if not humanoid or humanoid.Health <= 0 or damage <= 0 then return false end

	humanoid:TakeDamage(damage)
	if target:IsA("Player") then
		fireHealthUpdated(target, humanoid)
	end
	return true
end

function HealthService.set_health(target: HealthTarget, health: number): boolean
	local humanoid = resolveHumanoid(target)
	if not humanoid then return false end

	local updatedHealth = math.clamp(health, 0, humanoid.MaxHealth)
	if humanoid.Health == updatedHealth then return false end

	humanoid.Health = updatedHealth
	if target:IsA("Player") then
		fireHealthUpdated(target, humanoid)
	end
	return true
end

function HealthService:Init()
	_healthUpdatedRemote = Framework.CreateRemote(RemoteNames.PLAYER_HEALTH_UPDATED)
end

function HealthService:Start()
	SkillService.onHealthModifierChanged(applyHealthModifier)
	CharacterService.onCharacterReady(onCharacterReady)
end

Framework.CreateService(HealthService)

return HealthService
