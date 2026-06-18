--!strict

local GunHitScanModule = {}

export type ShotResult = {
	hitPosition: Vector3,
	hitZombie: Model?,
	hitPart: BasePart?,
	isHeadshot: boolean,
}

function GunHitScanModule.castShot(mouse: Mouse, character: Model?, origin: Vector3, range: number): ShotResult
	local aim = mouse and mouse.Hit and mouse.Hit.Position or nil
	if not aim then
		return {
			hitPosition = origin,
			hitZombie = nil,
			hitPart = nil,
			isHeadshot = false,
		}
	end

	local directionUnit = (aim - origin).Unit
	if directionUnit.Magnitude == 0 then
		directionUnit = Vector3.new(0, 0, 1)
	end

	local params = RaycastParams.new()
	if character then
		params.FilterDescendantsInstances = { character }
	end
	params.FilterType = Enum.RaycastFilterType.Exclude

	local remaining = range
	local currentOrigin = origin
	local maxIter = 50

	for i = 1, maxIter do
		if remaining <= 0 then break end
		local rayDir = directionUnit * remaining
		local result = workspace:Raycast(currentOrigin, rayDir, params)
		if not result then
			-- no more hits within remaining range
			return {
				hitPosition = origin + directionUnit * range,
				hitZombie = nil,
				hitPart = nil,
				isHeadshot = false,
			}
		end

		local hitPart = result.Instance and result.Instance:IsA("BasePart") and result.Instance :: BasePart or nil
		local ancestor = result.Instance and result.Instance:FindFirstAncestorOfClass("Model")
		local zombie = (ancestor and ancestor.Name == "Zombie") and ancestor :: Model or nil

		if zombie then
			local isHeadshot = hitPart and hitPart.Name:lower():find("head") ~= nil or false
			return {
				hitPosition = result.Position,
				hitZombie = zombie,
				hitPart = hitPart,
				isHeadshot = isHeadshot,
			}
		end

		-- Ignore this hit and continue from just past the hit point
		local traveled = (result.Position - currentOrigin).Magnitude
		remaining = remaining - traveled
		if remaining <= 0 then break end
		currentOrigin = result.Position + directionUnit * 0.01
	end

	-- Nothing hit (or reached iteration limit): return endpoint at full range
	return {
		hitPosition = origin + directionUnit * range,
		hitZombie = nil,
		hitPart = nil,
		isHeadshot = false,
	}
end

function GunHitScanModule.findHitZombie(mouse: Mouse, character: Model?, origin: Vector3, range: number): Model?
	return GunHitScanModule.castShot(mouse, character, origin, range).hitZombie
end

return GunHitScanModule
