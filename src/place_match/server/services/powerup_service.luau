--!strict

local Players = game:GetService("Players")
local debris = game:GetService("Debris")
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
	pickup: PVInstance,
	trigger: BasePart,
	parts: { BasePart },
	powerupType: PowerupType,
	claimed: boolean,
}

type BattleState = {
	active: boolean,
	pickups: { [PVInstance]: PickupRecord },
}

local PowerupService = {}
PowerupService.Name = TAG

local _battleStateByPlayer: { [Player]: BattleState } = {}
local _pickupRecordByPart: { [BasePart]: PickupRecord } = {}

local POWERUP_MODEL_NAMES: { [PowerupType]: string } = {
	Food = "TurkeyLeg",
	DoubleXp = "2x",
	MaxAmmo = "MaxAmmo",
}

local POWERUP_SOUND_IDS: { [PowerupType]: string } = {
	Food = "rbxassetid://137102366884896",
	DoubleXp = "rbxassetid://113159623717183",
	MaxAmmo = "rbxassetid://76008907639113",
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
		battle.pickups[record.pickup] = nil
	end
	for _, part in record.parts do
		_pickupRecordByPart[part] = nil
	end
	if record.pickup.Parent then
		record.pickup:Destroy()
	end
	if record.trigger.Parent then
		record.trigger:Destroy()
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

local function playPowerupSound(rootPart: BasePart, powerupType: PowerupType)
	local sound = Instance.new("Sound")
	sound.SoundId = POWERUP_SOUND_IDS[powerupType]
	sound.Parent = rootPart
	sound:Play()
	debris:AddItem(sound, 10)
end

local function createPickupTrigger(position: Vector3): BasePart
	local trigger = Instance.new("Part")
	trigger.Name = "PickupTrigger"
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.CanTouch = true
	trigger.Transparency = 1
	trigger.Size = Vector3.one * (PowerupConfig.PICKUP_RADIUS * 2)
	trigger.CFrame = CFrame.new(position)
	trigger.Parent = workspace
	return trigger
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
	if not record or record.claimed or not record.pickup.Parent then
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

	assert(record.pickup.Parent, "Active powerup pickup must remain parented")
	if (rootPart.Position - record.pickup:GetPivot().Position).Magnitude > PowerupConfig.PICKUP_RADIUS then
		return
	end

	record.claimed = true
	destroyPickup(record)
	playPowerupSound(rootPart, record.powerupType)
	applyPowerup(player, record.powerupType)
	Logger.info(TAG, "%s collected %s.", player.Name, record.powerupType)
end

local function spawnPickup(player: Player, position: Vector3, powerupType: PowerupType)
	local powerupFolder = replicated_storage:FindFirstChild("PowerUp")
	assert(powerupFolder and powerupFolder:IsA("Folder"), "ReplicatedStorage.PowerUp folder is required")
	local template = powerupFolder:FindFirstChild(POWERUP_MODEL_NAMES[powerupType], true)
	assert(template, string.format("Missing PowerUp template for %s", powerupType))
	assert(template:IsA("Model") or template:IsA("BasePart"), string.format("PowerUp template '%s' must be a Model or BasePart", template.Name))
	local pickup = template:Clone() :: PVInstance
	pickup:PivotTo(CFrame.new(position + Vector3.new(0, 2, 0)))
	pickup.Parent = workspace

	local parts: { BasePart } = {}
	if pickup:IsA("BasePart") then
		table.insert(parts, pickup)
	end
	for _, descendant in pickup:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	assert(#parts > 0, string.format("PowerUp model '%s' requires a BasePart", template.Name))
	local trigger = createPickupTrigger(pickup:GetPivot().Position)
	table.insert(parts, trigger)

	local record: PickupRecord = {
		owner = player,
		pickup = pickup,
		trigger = trigger,
		parts = parts,
		powerupType = powerupType,
		claimed = false,
	}
	local battle = assert(getBattleState(player), string.format("Missing battle state for %s", player.Name))
	for _, part in parts do
		_pickupRecordByPart[part] = record
		part.Touched:Connect(onPickupTouched)
	end
	battle.pickups[pickup] = record
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

	spawnPickup(player, deathPosition, choosePowerupType())
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