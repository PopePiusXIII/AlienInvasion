--!strict

local TweenService = game:GetService("TweenService")

local ZombieDamageHud = {}

local DISPLAY_DURATION = 0.7

local function destroyPopup(popup: BillboardGui)
	popup:Destroy()
end

function ZombieDamageHud.show(zombieModel: Model, damageAmount: number, isHeadshot: boolean)
	local rootPart = zombieModel:FindFirstChild("HumanoidRootPart")
	assert(rootPart and rootPart:IsA("BasePart"), "Damaged zombie is missing HumanoidRootPart")
	assert(damageAmount > 0, "Damage popup requires a positive damage amount")

	local popup = Instance.new("BillboardGui")
	popup.Name = "DamagePopup"
	popup.Adornee = rootPart
	popup.AlwaysOnTop = true
	popup.LightInfluence = 0
	popup.Size = UDim2.fromOffset(110, 48)
	popup.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	popup.Parent = rootPart

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = string.format("%d", damageAmount)
	label.TextColor3 = if isHeadshot then Color3.fromRGB(255, 215, 66) else Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	label.TextStrokeTransparency = 0.2
	label.Parent = popup

	local moveTween = TweenService:Create(
		popup,
		TweenInfo.new(DISPLAY_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, 5, 0) }
	)
	local fadeTween = TweenService:Create(
		label,
		TweenInfo.new(DISPLAY_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	local function onFadeComplete(_playbackState: Enum.PlaybackState)
		destroyPopup(popup)
	end

	moveTween:Play()
	fadeTween:Play()
	fadeTween.Completed:Once(onFadeComplete)
end

return ZombieDamageHud
