--!strict

local ClerkInteractionModule = {}

-- Shared handler registry: player name → onClaim callback.
local _handlers: { [string]: () -> () } = {}

-- Cached prompt so we only create one across all players.
local _prompt: ProximityPrompt? = nil

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

local function ensurePrompt(): ProximityPrompt?
	if _prompt and _prompt.Parent then return _prompt end

	local clerkPart = findClerkPart()
	if not clerkPart then return nil end

	-- Clean up any stale prompts from previous runs.
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
		local handler = _handlers[triggeringPlayer.Name]
		if handler then
			handler()
		end
	end)

	_prompt = prompt
	return prompt
end

function ClerkInteractionModule.attach(player: Player, onClaim: () -> ()): boolean
	if not ensurePrompt() then return false end
	_handlers[player.Name] = onClaim
	return true
end

function ClerkInteractionModule.detach(player: Player): nil
	_handlers[player.Name] = nil
end

function ClerkInteractionModule.cleanup(): nil
	_handlers = {}
	if _prompt and _prompt.Parent then
		_prompt:Destroy()
		_prompt = nil
	end
end

return ClerkInteractionModule
