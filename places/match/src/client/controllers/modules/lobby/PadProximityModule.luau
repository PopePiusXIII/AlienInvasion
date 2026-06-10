--!strict

local RunService = game:GetService("RunService")

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

	localPlayer.CharacterAdded:Connect(function()
		playing = false
	end)

	local button = playPrompt:FindFirstChild("PlayButton") :: TextButton?
	if button then
		button.MouseButton1Click:Connect(function()
			playing = true
			onCommitPlay()
		end)
	end

	RunService.Heartbeat:Connect(function()
		if playing then
			playPrompt.Visible = false
			return
		end

		local char = getCharacter()
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		playPrompt.Visible = root ~= nil
			and (root :: BasePart).Position.X ~= math.huge
			and ((root :: BasePart).Position - pad.Position).Magnitude <= threshold
	end)
end

return PadProximityModule
