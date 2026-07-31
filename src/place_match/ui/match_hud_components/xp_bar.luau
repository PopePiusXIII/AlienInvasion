--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local vide = require(replicated_storage.Packages.vide)
local ComponentTypes = require(script.Parent.component_types)

local create = vide.create
local derive = vide.derive

export type Props = {
	colors: ComponentTypes.ColorSources,
	currentXP: vide.Source<number>,
	requiredXP: vide.Source<number>,
	xpPercent: vide.Source<number>,
}

local function XpBar(props: Props): Frame
	local xpText = derive(function()
		return string.format("%d/%d", props.currentXP(), props.requiredXP())
	end)

	return create "Frame" {
		Name = "XP_Frame",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(1877, 46),

		create "ImageLabel" {
			Name = "Purple_Background",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = props.colors.white,
			Image = "rbxassetid://106909274584862",
			ImageColor3 = props.colors.white,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),

			create "UIStroke" {
				Name = "UIStroke",
				Color = props.colors.purpleStroke,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.01,
			},

			create "TextLabel" {
				Name = "XP_Text_Label",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/RobotoMono.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Italic
				),
				Position = UDim2.new(0, 15, 0.463684, 0),
				Size = UDim2.fromScale(0.0158279, 0.627368),
				Text = "XP",
				TextColor3 = props.colors.purple,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,

				create "UIStroke" {
					Name = "UIStroke",
					Color = props.colors.purple,
					LineJoinMode = Enum.LineJoinMode.Miter,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.03125,
				},
			},

			create "UICorner" {
				Name = "UICorner",
			},
		},

		create "Frame" {
			Name = "Grey_Background_Frame",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = props.colors.grey,
			BorderColor3 = props.colors.black,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.9),

			create "UIStroke" {
				Name = "UIStroke",
				Color = props.colors.black,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.0344828,
			},
		},

		create "Frame" {
			Name = "Purple_HealthBar",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = props.colors.purple,
			BorderColor3 = props.colors.black,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.05, 0.5),
			Size = function()
				return UDim2.fromScale(0.9 * math.clamp(props.xpPercent(), 0, 1), 0.85)
			end,

			create "UIGradient" {
				Name = "UIGradient",
				Color = function()
					return ColorSequence.new({
						ColorSequenceKeypoint.new(0, props.colors.xpGradientStart()),
						ColorSequenceKeypoint.new(1, props.colors.xpGradientEnd()),
					})
				end,
			},
		},

		create "TextLabel" {
			Name = "TextLabel",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json"),
			Position = UDim2.new(0.5, 0, 0, -10),
			Size = UDim2.fromScale(0.334302, 0.24),
			Text = xpText,
			TextColor3 = props.colors.purple,
			TextScaled = true,

			create "UIStroke" {
				Name = "UIStroke",
				Color = props.colors.black,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.00625,
			},
		},

		create "UIAspectRatioConstraint" {
			Name = "UIAspectRatioConstraint",
			AspectRatio = 53.85,
			AspectType = Enum.AspectType.ScaleWithParentSize,
		},
	}
end

return XpBar
