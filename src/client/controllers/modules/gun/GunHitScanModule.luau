--!strict

local GunHitScanModule = {}

function GunHitScanModule.findHitZombie(mouse: Mouse, character: Model?, origin: Vector3, range: number): Model?
	local direction = (mouse.Hit.Position - origin).Unit * range
	local params    = RaycastParams.new()
	if character then
		params.FilterDescendantsInstances = { character }
	end
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, direction, params)
	if not result then return nil end

	local ancestor = result.Instance:FindFirstAncestorOfClass("Model")
	return (ancestor and ancestor.Name == "Zombie") and ancestor :: Model or nil
end

return GunHitScanModule
