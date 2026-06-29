--!strict

local ServerStorage = game:GetService("ServerStorage")

local LoadoutGrantModule = {}

local function findWeaponSource(gunName: string): Instance?
	local found = ServerStorage:FindFirstChild(gunName, true)
	if found and (found:IsA("Tool") or found:IsA("Model")) then
		return found
	end
	return nil
end

local function ensureHandle(tool: Tool): BasePart?
	local directHandle = tool:FindFirstChild("Handle")
	if directHandle and directHandle:IsA("BasePart") then
		return directHandle :: BasePart
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Name = "Handle"
			descendant.Parent = tool
			return descendant :: BasePart
		end
	end

	return nil
end

local function normalizeToolPhysics(tool: Tool)
	local handle = ensureHandle(tool)
	if not handle then return end

	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= handle then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
end

local function cloneWeaponAsTool(gunName: string): Tool?
	local source = findWeaponSource(gunName)
	if not source then return nil end

	if source:IsA("Tool") then
		local toolClone = (source :: Tool):Clone()
		normalizeToolPhysics(toolClone)
		return toolClone
	end

	if source:IsA("Model") then
		local tool = Instance.new("Tool")
		tool.Name = gunName
		tool.RequiresHandle = true

		local modelClone = (source :: Model):Clone()
		modelClone.Parent = tool

		normalizeToolPhysics(tool)
		return tool
	end

	return nil
end

function LoadoutGrantModule.grant(player: Player, desiredGunNames: { string }, onWarn: (message: string, ...any) -> ()): number
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack or not backpack:IsA("Backpack") then
		onWarn("Backpack missing for %s; couldn't grant loadout.", player.Name)
		return 0
	end

	if typeof(desiredGunNames) ~= "table" or #desiredGunNames == 0 then
    onWarn("No desired gun names provided for %s; nothing to grant.", player.Name)
    return 0
end

	local granted = 0
	for _, gunName in ipairs(desiredGunNames) do
		onWarn("give '%s' to '%s'", gunName, player.Name)
		local weaponTool = cloneWeaponAsTool(gunName)
		if weaponTool then
			local hasInBackpack = backpack:FindFirstChild(weaponTool.Name) ~= nil
			local character = player.Character
			local hasEquipped = character and character:FindFirstChild(weaponTool.Name) ~= nil
			if not hasInBackpack and not hasEquipped then
				weaponTool.Parent = backpack
				granted += 1
			else
				weaponTool:Destroy()
			end
		else
			onWarn("Configured weapon '%s' (Tool or Model) was not found in ServerStorage.", gunName)
		end
	end

	if granted == 0 then
		onWarn("No guns granted to %s (already had both weapons or templates missing).", player.Name)
	end

	return granted
end

return LoadoutGrantModule
