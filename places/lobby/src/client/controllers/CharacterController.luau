--!strict
--------------------------------------------------------------------------------
-- CharacterController.luau  (places/lobby/src/client/controllers)
-- Applies walk/sprint/jump stats to the local character in the Lobby place.
-- Mirrors the Match place CharacterController, minus wave-boost public API.
--------------------------------------------------------------------------------

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)

local TAG = "CharacterController"

local CharacterController = Framework.CreateController({ Name = TAG })

local _localPlayer = Players.LocalPlayer
local _isSprinting = false

local function getHumanoid(): Humanoid?
	local char = _localPlayer.Character
	return char and char:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
end

local function applyStats(humanoid: Humanoid)
	humanoid.WalkSpeed = _isSprinting and Config.PLAYER_SPRINT_SPEED or Config.PLAYER_WALK_SPEED
	humanoid.JumpPower = Config.PLAYER_JUMP_POWER
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	_isSprinting = false
	applyStats(humanoid)
end

function CharacterController:Init()
	_localPlayer.CharacterAdded:Connect(onCharacterAdded)
	if _localPlayer.Character then
		onCharacterAdded(_localPlayer.Character)
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			_isSprinting = true
			local humanoid = getHumanoid()
			if humanoid then humanoid.WalkSpeed = Config.PLAYER_SPRINT_SPEED end
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			_isSprinting = false
			local humanoid = getHumanoid()
			if humanoid then humanoid.WalkSpeed = Config.PLAYER_WALK_SPEED end
		end
	end)

	Logger.info(TAG, "Initialized.")
end

return CharacterController
