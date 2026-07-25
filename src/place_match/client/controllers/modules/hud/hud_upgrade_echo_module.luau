--!strict

local TweenService = game:GetService("TweenService")

local HudUpgradeEchoModule = {}

function HudUpgradeEchoModule.show(parent: ScreenGui, speedBoost: number, scaleBoost: number)
	local echo                  = Instance.new("TextLabel")
	echo.Name                   = "UpgradeEcho"
	echo.Size                   = UDim2.new(0.4, 0, 0.08, 0)
	echo.Position               = UDim2.new(0.3, 0, 0.42, 0)
	echo.BackgroundTransparency = 1
	echo.TextColor3             = Color3.fromRGB(255, 210, 50)
	echo.TextStrokeTransparency = 0.4
	echo.TextScaled             = true
	echo.Font                   = Enum.Font.GothamBold
	echo.Text                   = string.format("+%d SPD  •  +%d%% SIZE", speedBoost, math.round(scaleBoost * 100))
	echo.Parent = parent

	local tween = TweenService:Create(
		echo,
		TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.3, 0, 0.28, 0), TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Connect(function()
		echo:Destroy()
	end)
end

return HudUpgradeEchoModule
