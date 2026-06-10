--!strict

local GunHitScanModule = {}

export type ShotResult = {
	hitPosition: Vector3,
	hitZombie: Model?,
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
		}
	end

	local ancestor = result.Instance:FindFirstAncestorOfClass("Model")
	local zombie = (ancestor and ancestor.Name == "Zombie") and ancestor :: Model or nil

	return {
		hitPosition = result.Position,
		hitZombie = zombie,
	}
end

function GunHitScanModule.findHitZombie(mouse: Mouse, character: Model?, origin: Vector3, range: number): Model?
	return GunHitScanModule.castShot(mouse, character, origin, range).hitZombie
end

return GunHitScanModule
