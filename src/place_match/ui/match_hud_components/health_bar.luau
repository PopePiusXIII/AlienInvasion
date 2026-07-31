--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local vide = require(replicated_storage.Packages.vide)
local ComponentTypes = require(script.Parent.component_types)

local create = vide.create
local derive = vide.derive

export type Props = {
	colors: ComponentTypes.ColorSources,
	healthPercent: vide.Source<number>,
}

local function HealthBar(props: Props): Frame
	local healthText = derive(function()
		return string.format("%d / 100", math.round(math.clamp(props.healthPercent(), 0, 100)))
	end)

	return create "Frame" {
		Name = "Health_Frame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.117647, 0.928571),
		Size = UDim2.fromScale(0.198385, 0.0892857),

		create "ImageLabel" {
			Name = "Purple_Background",
			BackgroundColor3 = props.colors.white,
			Image = "rbxassetid://106909274584862",
			ImageColor3 = props.colors.white,
			Position = UDim2.fromScale(-0.0472093, 0.29),
			Size = UDim2.fromScale(0.997093, 0.76),

			create "UIStroke" {
				Name = "UIStroke",
				Color = props.colors.purpleStroke,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.01,
			},

			create "TextLabel" {
				Name = "HP",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/RobotoMono.json",
					Enum.FontWeight.Regular,
					Enum.FontStyle.Italic
				),
				Position = UDim2.fromScale(0.0612026, 0.0954654),
				Size = UDim2.fromScale(0.103316, 0.354737),
				Text = "HP",
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
				BottomLeftRadius = UDim.new(0, 4),
				BottomRightRadius = UDim.new(0, 4),
				TopLeftRadius = UDim.new(0, 4),
				TopRightRadius = UDim.new(0, 4),
			},
		},

		create "Frame" {
			Name = "Grey_Background_Frame",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = props.colors.grey,
			BorderColor3 = props.colors.black,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.453488, 0.795),
			Size = UDim2.fromScale(0.912791, 0.29),

			create "UIStroke" {
				Name = "UIStroke",
				Color = props.colors.black,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.0344828,
			},
		},

		create "Frame" {
			Name = "Purple_HealthBar",
			BackgroundColor3 = props.colors.purple,
			BorderColor3 = props.colors.black,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(-0.00290698, 0.65),
			Size = function()
				return UDim2.fromScale(0.912791 * math.clamp(props.healthPercent(), 0, 100) / 100, 0.29)
			end,
		},

		create "TextLabel" {
			Name = "HealthValue",
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/RobotoMono.json",
				Enum.FontWeight.Regular,
				Enum.FontStyle.Italic
			),
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.336492, 0.68973),
			Size = UDim2.fromScale(0.235474, 0.21),
			Text = healthText,
			TextColor3 = props.colors.black,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 2,

			create "UIStroke" {
				Name = "UIStroke",
				Color = props.colors.purple,
				LineJoinMode = Enum.LineJoinMode.Miter,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.03125,
			},
		},
	}
end

return HealthBar
