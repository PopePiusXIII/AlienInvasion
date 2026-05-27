--!strict

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local localPlayer = Players.LocalPlayer

local CharacterManager = {}

export type StatName = "walkSpeed" | "sprintSpeed" | "jumpPower" | "meleePower" | "scale"

export type Stats = {
	walkSpeed:   number,
	sprintSpeed: number,
	jumpPower:   number,
	meleePower:  number,
	scale:       number,
}

local stats: Stats = {
	walkSpeed   = Config.PLAYER_WALK_SPEED,
	sprintSpeed = Config.PLAYER_SPRINT_SPEED,
	jumpPower   = Config.PLAYER_JUMP_POWER,
	meleePower  = Config.PLAYER_MELEE_POWER,
	scale       = Config.PLAYER_SCALE,
}

local isSprinting: boolean = false

local function getHumanoid(): Humanoid?
	local char = localPlayer.Character
	return char and char:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
end

local function applyScale(humanoid: Humanoid)
	local names = { "BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale" }
	for _, name in names do
		local v = humanoid:FindFirstChild(name)
		if v and v:IsA("NumberValue") then
			(v :: NumberValue).Value = stats.scale
		end
	end
end

local function applyStats(humanoid: Humanoid)
	humanoid.WalkSpeed = isSprinting and stats.sprintSpeed or stats.walkSpeed
	humanoid.JumpPower = stats.jumpPower
	applyScale(humanoid)
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	isSprinting    = false
	applyStats(humanoid)
end

function CharacterManager.boostStat(stat: StatName, delta: number)
	stats[stat] += delta
	local humanoid = getHumanoid()
	if humanoid then
		applyStats(humanoid)
	end
end

function CharacterManager.setStat(stat: StatName, value: number)
	stats[stat] = value
	local humanoid = getHumanoid()
	if humanoid then
		applyStats(humanoid)
	end
end

function CharacterManager.resetStats()
	stats = {
		walkSpeed   = Config.PLAYER_WALK_SPEED,
		sprintSpeed = Config.PLAYER_SPRINT_SPEED,
		jumpPower   = Config.PLAYER_JUMP_POWER,
		meleePower  = Config.PLAYER_MELEE_POWER,
		scale       = Config.PLAYER_SCALE,
	}
	local humanoid = getHumanoid()
	if humanoid then
		applyStats(humanoid)
	end
end

function CharacterManager.getStats(): Stats
	return table.clone(stats)
end

function CharacterManager.init()
	localPlayer.CharacterAdded:Connect(onCharacterAdded)
	if localPlayer.Character then
		onCharacterAdded(localPlayer.Character)
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		local humanoid = getHumanoid()
		if not humanoid then return end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			isSprinting            = true
			humanoid.WalkSpeed     = stats.sprintSpeed
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		local humanoid = getHumanoid()
		if not humanoid then return end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			isSprinting        = false
			humanoid.WalkSpeed = stats.walkSpeed
		end
	end)
end

return CharacterManager
