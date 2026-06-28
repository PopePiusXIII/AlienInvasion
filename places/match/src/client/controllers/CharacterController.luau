--!strict
--------------------------------------------------------------------------------
-- CharacterController.luau  (src/client/controllers)
-- Manages local character stats: walk speed, sprint speed, jump power, scale.
-- Single Responsibility: stat state and application only.
-- No RemoteEvents. No UI. No game-mode awareness.
--
-- Public API:
--   CharacterController.boostStat(stat, delta)   — adds delta to a stat
--   CharacterController.setStat(stat, value)     — sets a stat to an exact value
--   CharacterController.getStats()               — returns a snapshot table
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)

local TAG = "CharacterController"

export type StatName = "walkSpeed" | "sprintSpeed" | "jumpPower" | "meleePower" | "scale"

export type Stats = {
	walkSpeed:   number,
	sprintSpeed: number,
	jumpPower:   number,
	meleePower:  number,
	scale:       number,
}

local CharacterController = Framework.CreateController({ Name = TAG })

local _localPlayer = Players.LocalPlayer
local _isSprinting = false
local _rotateWithCameraConn: RBXScriptConnection? = nil
local _inputBeganConn: RBXScriptConnection? = nil
local _inputEndedConn: RBXScriptConnection? = nil

-- Rotation config
local SMOOTH_ROTATION = true
local ROTATION_LERP_SPEED = 12 -- higher = snappier (per second)

-- Mutable stats table — the single source of truth for this controller.
local _stats: Stats = {
	walkSpeed   = Config.PLAYER_WALK_SPEED,
	sprintSpeed = Config.PLAYER_SPRINT_SPEED,
	jumpPower   = Config.PLAYER_JUMP_POWER,
	meleePower  = Config.PLAYER_MELEE_POWER,
	scale       = Config.PLAYER_SCALE,
}

-- ── Private helpers ───────────────────────────────────────────────────────────

local function getHumanoid(): Humanoid?
	local char = _localPlayer.Character
	return char and char:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
end

local function getRootPart(character: Model): BasePart?
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	local primary = character.PrimaryPart
	if primary and primary:IsA("BasePart") then return primary end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head end
	return nil
end

local function applyScale()
	local character = _localPlayer.Character
	if character then
		(character :: Model):ScaleTo(_stats.scale)
	end
end

local function applyStats(humanoid: Humanoid)
	humanoid.WalkSpeed = _isSprinting and _stats.sprintSpeed or _stats.walkSpeed
	humanoid.JumpPower = _stats.jumpPower
	applyScale()
end

local function resetStatsTable()
	_stats = {
		walkSpeed   = Config.PLAYER_WALK_SPEED,
		sprintSpeed = Config.PLAYER_SPRINT_SPEED,
		jumpPower   = Config.PLAYER_JUMP_POWER,
		meleePower  = Config.PLAYER_MELEE_POWER,
		scale       = Config.PLAYER_SCALE,
	}
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	_isSprinting   = false
	-- Reset accumulated wave boosts on each respawn.
	resetStatsTable()
	applyStats(humanoid)
	-- Prevent the humanoid from auto-rotating when moving so WASD strafes
	if humanoid and humanoid:IsA("Humanoid") then
		pcall(function()
			humanoid.AutoRotate = false
		end)
	end
end

-- Rotation helpers ---------------------------------------------------------
local function stopRotateWithCamera()
	if _rotateWithCameraConn then
		_rotateWithCameraConn:Disconnect()
		_rotateWithCameraConn = nil
	end
end

local function startRotateWithCamera()
	stopRotateWithCamera()
	_rotateWithCameraConn = RunService.RenderStepped:Connect(function(dt)
		local char = _localPlayer.Character
		if not char then return end
		local root = getRootPart(char)
		local cam = workspace.CurrentCamera
		if root and cam then
			local look = cam.CFrame.LookVector
			local dir = Vector3.new(look.X, 0, look.Z)
			if dir.Magnitude > 0.001 then
				local target = CFrame.new(root.Position, root.Position + dir)
				if SMOOTH_ROTATION then
					root.CFrame = root.CFrame:Lerp(target, math.clamp(ROTATION_LERP_SPEED * dt, 0, 1))
				else
					root.CFrame = target
				end
			end
		end
	end)
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function CharacterController:Init()
	_localPlayer.CharacterAdded:Connect(onCharacterAdded)
	if _localPlayer.Character then
		onCharacterAdded(_localPlayer.Character)
	end

	local function onInputBegan(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			_isSprinting = true
			local humanoid = getHumanoid()
			if humanoid then humanoid.WalkSpeed = _stats.sprintSpeed end
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			startRotateWithCamera()
		end
	end

	local function onInputEnded(input: InputObject)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			_isSprinting = false
			local humanoid = getHumanoid()
			if humanoid then humanoid.WalkSpeed = _stats.walkSpeed end
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			stopRotateWithCamera()
		end
	end

	_inputBeganConn = UserInputService.InputBegan:Connect(onInputBegan)
	_inputEndedConn = UserInputService.InputEnded:Connect(onInputEnded)

	Logger.info(TAG, "Initialized.")
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Accumulate a delta onto a stat (e.g. wave-clear speed boost).
function CharacterController.boostStat(stat: StatName, delta: number)
	_stats[stat] += delta
	local humanoid = getHumanoid()
	if humanoid then applyStats(humanoid) end
end

--- Overwrite a stat with an exact value.
function CharacterController.setStat(stat: StatName, value: number)
	_stats[stat] = value
	local humanoid = getHumanoid()
	if humanoid then applyStats(humanoid) end
end

--- Returns a shallow copy of the current stat table (safe to read, not to mutate).
function CharacterController.getStats(): Stats
	return table.clone(_stats)
end

return CharacterController
