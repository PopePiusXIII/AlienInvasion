--!strict

local replicated_storage = game:GetService("ReplicatedStorage")

local Logger = require(replicated_storage.common.shared.logger)
local Config = require(replicated_storage.match.shared.configs.zombie_config)

local TAG = "ZombieLiftModule"
local ZOMBIE_LIFT_ZONE_ATTRIBUTE = "ZombieLiftZone"

local ZombieLiftModule = {}
local _liftZones: { BasePart } = {}

local function isPositionInsideLiftZone(position: Vector3, liftZone: BasePart): boolean
	local localPosition = liftZone.CFrame:PointToObjectSpace(position)
	local halfSize = liftZone.Size * 0.5
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function isPositionInLiftZone(position: Vector3): boolean
	for _, liftZone in ipairs(_liftZones) do
		if isPositionInsideLiftZone(position, liftZone) then
			return true
		end
	end
	return false
end

function ZombieLiftModule.initialize()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:GetAttribute(ZOMBIE_LIFT_ZONE_ATTRIBUTE) == true then
			assert(descendant:IsA("BasePart"),
				"[ZombieLiftModule] ZombieLiftZone must be a BasePart: " .. descendant:GetFullName())
			table.insert(_liftZones, descendant)
			Logger.info(TAG, "Zombie lift zone cached: %s", descendant:GetFullName())
		end
	end

	assert(#_liftZones > 0, "[ZombieLiftModule] No ZombieLiftZone BasePart found in Workspace.")
end

function ZombieLiftModule.update(root: BasePart)
	if not isPositionInLiftZone(root.Position) then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, Config.ZOMBIE_LIFT_SPEED, velocity.Z)
end

return ZombieLiftModule