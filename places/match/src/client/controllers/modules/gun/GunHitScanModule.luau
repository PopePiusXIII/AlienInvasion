--!strict

local GunHitScanModule = {}

export type ShotResult = {
	hitPosition: Vector3,
	hitZombie: Model?,
	hitPart: BasePart?,
	isHeadshot: boolean,
}

function GunHitScanModule.castShot(mouse: Mouse, character: Model?, origin: Vector3, range: number): ShotResult
	local direction = (mouse.Hit.Position - origin).Unit * range
	local params    = RaycastParams.new()
	if character then
		params.FilterDescendantsInstances = { character }
	end
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, direction, params)
	if not result then
		return {
			hitPosition = origin + direction,
			hitZombie = nil,
			hitPart = nil,
			isHeadshot = false,
		}
	end

	local hitPart = result.Instance:IsA("BasePart") and result.Instance :: BasePart or nil
	local isHeadshot = hitPart and hitPart.Name:lower():find("head") ~= nil or false

	local ancestor = result.Instance:FindFirstAncestorOfClass("Model")
	local zombie = (ancestor and ancestor.Name == "Zombie") and ancestor :: Model or nil

	return {
		hitPosition = result.Position,
		hitZombie = zombie,
		hitPart = hitPart,
		isHeadshot = isHeadshot,
	}
end

function GunHitScanModule.findHitZombie(mouse: Mouse, character: Model?, origin: Vector3, range: number): Model?
	return GunHitScanModule.castShot(mouse, character, origin, range).hitZombie
end

return GunHitScanModule
