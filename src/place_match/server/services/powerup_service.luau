--!strict

local Players = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)
local PowerupConfig = require(replicated_storage.match.shared.configs.powerup_config)
local CharacterLevelService = require(server_script_service.match.services.character_level_service)
local GunService = require(server_script_service.match.services.gun_service)
local HealthService = require(server_script_service.match.services.health_service)

local TAG = "PowerupService"

type PowerupType = "Food" | "DoubleXp" | "MaxAmmo"

type PickupRecord = {
	owner: Player,
	part: BasePart,
	powerupType: PowerupType,
	claimed: boolean,
}

type BattleState = {
	active: boolean,
	pickups: { [BasePart]: PickupRecord },
}

local PowerupService = {}
PowerupService.Name = TAG

local _battleStateByPlayer: { [Player]: BattleState } = {}
local _pickupRecordByPart: { [BasePart]: PickupRecord } = {}

local POWERUP_COLORS: { [PowerupType]: Color3 } = {
	Food = Color3.fromRGB(90, 220, 110),
	DoubleXp = Color3.fromRGB(255, 210, 70),
	MaxAmmo = Color3.fromRGB(90, 160, 255),
}

local function getBattleState(player: Player): BattleState?
	local battle = _battleStateByPlayer[player]
	if not battle or not battle.active then
		return nil
	end
	return battle
end

local function destroyPickup(record: PickupRecord)
	local battle = _battleStateByPlayer[record.owner]
	if battle then
		battle.pickups[record.part] = nil
	end
	_pickupRecordByPart[record.part] = nil
	if record.part.Parent then
		record.part:Destroy()
	end
end

local function expirePickup(record: PickupRecord)
	if record.claimed then
		return
	end
	destroyPickup(record)
end

local function schedulePickupExpiry(record: PickupRecord)
	task.delay(PowerupConfig.PICKUP_LIFETIME, expirePickup, record)
end

local function choosePowerupType(): PowerupType
	local totalWeight = PowerupConfig.FOOD_WEIGHT + PowerupConfig.DOUBLE_XP_WEIGHT + PowerupConfig.MAX_AMMO_WEIGHT
	local roll = math.random(1, totalWeight)
	if roll <= PowerupConfig.FOOD_WEIGHT then
		return "Food"
	end
	if roll <= PowerupConfig.FOOD_WEIGHT + PowerupConfig.DOUBLE_XP_WEIGHT then
		return "DoubleXp"
	end
	return "MaxAmmo"
end

local function applyPowerup(player: Player, powerupType: PowerupType)
	if powerupType == "Food" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		assert(humanoid, string.format("Cannot apply Food powerup without a Humanoid for %s", player.Name))
		HealthService.set_health(player, humanoid.Health + PowerupConfig.FOOD_HEALTH)
		return
	end

	if powerupType == "DoubleXp" then
		CharacterLevelService.activateDoubleXp(player, PowerupConfig.DOUBLE_XP_DURATION)
		return
	end

	GunService.replenishEquippedAmmo(player)
end

local function getPickupTouchedPart(hit: BasePart): BasePart?
	for _, touchingPart in ipairs(hit:GetTouchingParts()) do
		if _pickupRecordByPart[touchingPart] then
			return touchingPart
		end
	end
	return nil
end

local function onPickupTouched(hit: BasePart)
	local pickupPart = getPickupTouchedPart(hit)
	if not pickupPart then
		return
	end

	local record = _pickupRecordByPart[pickupPart]
	if not record or record.claimed or not record.part.Parent then
		return
	end

	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if player ~= record.owner or not getBattleState(player) then
		return
	end
	assert(character, "Powerup touch must have a character model")

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	assert(record.part.Parent, "Active powerup pickup must remain parented")
	if (rootPart.Position - record.part.Position).Magnitude > PowerupConfig.PICKUP_RADIUS then
		return
	end

	record.claimed = true
	destroyPickup(record)
	applyPowerup(player, record.powerupType)
	Logger.info(TAG, "%s collected %s.", player.Name, record.powerupType)
end

local function createPickup(player: Player, position: Vector3, powerupType: PowerupType)
	local pickup = Instance.new("Part")
	pickup.Name = powerupType
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.CanQuery = false
	pickup.Color = POWERUP_COLORS[powerupType]
	pickup.Material = Enum.Material.Neon
	pickup.Shape = Enum.PartType.Ball
	pickup.Size = Vector3.new(2, 2, 2)
	pickup.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
	pickup.Parent = workspace

	local record: PickupRecord = {
		owner = player,
		part = pickup,
		powerupType = powerupType,
		claimed = false,
	}
	local battle = assert(getBattleState(player), string.format("Missing battle state for %s", player.Name))
	battle.pickups[pickup] = record
	_pickupRecordByPart[pickup] = record
	pickup.Touched:Connect(onPickupTouched)
	schedulePickupExpiry(record)
end

function PowerupService.beginBattle(player: Player)
	PowerupService.endBattle(player)
	_battleStateByPlayer[player] = {
		active = true,
		pickups = {},
	}
	CharacterLevelService.clearDoubleXp(player)
end

function PowerupService.endBattle(player: Player)
	local battle = _battleStateByPlayer[player]
	if battle then
		battle.active = false
		for _, record in battle.pickups do
			destroyPickup(record)
		end
	end
	_battleStateByPlayer[player] = nil
	CharacterLevelService.clearDoubleXp(player)
end

function PowerupService.onZombieKilled(player: Player, deathPosition: Vector3?)
	if not deathPosition or not getBattleState(player) or math.random() > PowerupConfig.DROP_CHANCE then
		return
	end

	local battle = assert(getBattleState(player), string.format("Missing battle state for %s", player.Name))
	local activeCount = 0
	for _ in battle.pickups do
		activeCount += 1
	end
	if activeCount >= PowerupConfig.MAX_ACTIVE_PICKUPS then
		return
	end

	createPickup(player, deathPosition, choosePowerupType())
end

function PowerupService:Init()
end

function PowerupService:Start()
	local function onPlayerRemoving(player: Player)
		PowerupService.endBattle(player)
	end

	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

Framework.CreateService(PowerupService)

return PowerupService