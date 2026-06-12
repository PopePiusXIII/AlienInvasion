--!strict

local ClerkInteractionModule = {}

local function findClerkPart(): BasePart?
	local clerk = workspace:FindFirstChild("shopClerk", true)
	if not clerk then return nil end
	if clerk:IsA("BasePart") then
		return clerk :: BasePart
	end
	if clerk:IsA("Model") then
		local model = clerk :: Model
		if model.PrimaryPart then
			return model.PrimaryPart
		end
		local anyPart = model:FindFirstChildWhichIsA("BasePart", true)
		if anyPart then
			return anyPart :: BasePart
		end
	end
	return nil
end

function ClerkInteractionModule.attach(player: Player, onClaim: () -> ()): boolean
	local clerkPart = findClerkPart()
	if not clerkPart then return false end

	local existing = clerkPart:FindFirstChild("ShopClerkPrompt")
	if existing and existing:IsA("ProximityPrompt") then
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopClerkPrompt"
	prompt.ActionText = "Get Free Weapons"
	prompt.ObjectText = "Shop Clerk"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = clerkPart

	prompt.Triggered:Connect(function(triggeringPlayer: Player)
		if triggeringPlayer ~= player then return end
		onClaim()
	end)

	return true
end

return ClerkInteractionModule
