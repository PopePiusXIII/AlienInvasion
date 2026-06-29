--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RenderScheduler = require(Shared:WaitForChild("RenderScheduler"))

local PadProximityModule = {}

local function waitForGamePad(padName: string): BasePart
	while true do
		local found = workspace:FindFirstChild(padName, true)
		if found and found:IsA("BasePart") then
			return found :: BasePart
		end
		task.wait(1)
	end
end

function PadProximityModule.start(playPrompt: Frame, localPlayer: Player, padName: string, getCharacter: () -> Model?, onCommitPlay: () -> ())
	local pad       = waitForGamePad(padName)
	local threshold = 12
	local playing   = false
	local cachedHrp: BasePart? = nil

	localPlayer.CharacterAdded:Connect(function(character: Model)
		playing = false
		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		cachedHrp = (hrp and hrp:IsA("BasePart")) and hrp :: BasePart or nil
	end)
	localPlayer.CharacterRemoving:Connect(function()
		cachedHrp = nil
	end)
	if localPlayer.Character then
		local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
		cachedHrp = (hrp and hrp:IsA("BasePart")) and hrp :: BasePart or nil
	end

	local button = playPrompt:FindFirstChild("PlayButton") :: TextButton?
	if button then
		button.MouseButton1Click:Connect(function()
			playing = true
			onCommitPlay()
		end)
	end

	local _taskId = RenderScheduler.register("padProximity_" .. padName, function()
		if playing then
			playPrompt.Visible = false
			return
		end

		local root = cachedHrp
		playPrompt.Visible = root ~= nil
			and root.Position.X ~= math.huge
			and (root.Position - pad.Position).Magnitude <= threshold
	end, { enabled = true })
end

return PadProximityModule
