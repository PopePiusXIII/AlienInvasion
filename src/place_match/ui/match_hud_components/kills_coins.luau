--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local vide = require(replicated_storage.Packages.vide)
local ComponentTypes = require(script.Parent.component_types)

local create = vide.create

export type Props = {
	coins: vide.Source<number>,
	colors: ComponentTypes.ColorSources,
	kills: vide.Source<number>,
}

local function KillsCoins(props: Props): Frame
	return create "Frame" {
		Name = "Kills",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.0108309, 0.07),
		Size = UDim2.fromScale(0.130317, 0.0825394),

		create "UIAspectRatioConstraint" {
			Name = "UIAspectRatioConstraint",
			AspectRatio = 4.34,
		},

		create "ImageLabel" {
			Name = "ImageLabel",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://121467172736704",
			ImageColor3 = props.colors.white,
			Position = UDim2.fromScale(0.554454, 0.5),
			Size = UDim2.fromScale(0.0592586, 0.257182),
			ZIndex = 2,
		},

		create "TextLabel" {
			Name = "23",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/RobotoMono.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Italic
			),
			Position = UDim2.fromScale(0.810323, 0.5),
			Size = UDim2.fromScale(0.163036, 0.301018),
			Text = function()
				return tostring(props.coins())
			end,
			TextColor3 = props.colors.white,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 2,

			create "UIStroke" {
				Name = "UIStroke",
				Color = props.colors.white,
				LineJoinMode = Enum.LineJoinMode.Miter,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.015625,
			},
		},

		create "TextLabel" {
			Name = "KILLS",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/RobotoMono.json",
				Enum.FontWeight.Regular,
				Enum.FontStyle.Italic
			),
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.631603, 0.5),
			Size = UDim2.fromScale(0.160287, 0.288537),
			Text = "Coins",
			TextColor3 = props.colors.purple,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 2,

			create "UIStroke" {
				Name = "UIStroke",
				Color = props.colors.purple,
				LineJoinMode = Enum.LineJoinMode.Miter,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.015625,
			},
		},

		create "TextLabel" {
			Name = "KILLS",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/RobotoMono.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.431142, 0.5),
			Size = UDim2.fromScale(0.0804145, 0.863177),
			Text = "|",
			TextColor3 = props.colors.purple,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 2,

			create "UIStroke" {
				Name = "UIStroke",
				Color = props.colors.purple,
				LineJoinMode = Enum.LineJoinMode.Miter,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.015625,
			},
		},

		create "TextLabel" {
			Name = "23",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/RobotoMono.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Italic
			),
			Position = UDim2.fromScale(0.282673, 0.5),
			Size = UDim2.fromScale(0.163036, 0.301018),
			Text = function()
				return tostring(props.kills())
			end,
			TextColor3 = props.colors.white,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 2,

			create "UIStroke" {
				Name = "UIStroke",
				Color = props.colors.white,
				LineJoinMode = Enum.LineJoinMode.Miter,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.015625,
			},
		},

		create "ImageLabel" {
			Name = "ImageLabel",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://121467172736704",
			ImageColor3 = props.colors.white,
			Position = UDim2.fromScale(0.0221961, 0.5),
			Size = UDim2.fromScale(0.0592586, 0.257182),
			ZIndex = 2,
		},

		create "TextLabel" {
			Name = "KILLS",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/RobotoMono.json",
				Enum.FontWeight.Regular,
				Enum.FontStyle.Italic
			),
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.0970407, 0.5),
			Size = UDim2.fromScale(0.160287, 0.288537),
			Text = "KILLS",
			TextColor3 = props.colors.purple,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 2,

			create "UIStroke" {
				Name = "UIStroke",
				Color = props.colors.purple,
				LineJoinMode = Enum.LineJoinMode.Miter,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.015625,
			},
		},

		create "ImageLabel" {
			Name = "Purple_Background_Image",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = props.colors.white,
			Image = "rbxassetid://106909274584862",
			ImageColor3 = props.colors.white,
			Position = UDim2.fromScale(-0.00560117, 0.5),
			Size = UDim2.fromScale(1.00099, 1),

			create "UIStroke" {
				Name = "UIStroke",
				Color = props.colors.purpleStroke,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.02,
			},

			create "UICorner" {
				Name = "UICorner",
				BottomLeftRadius = UDim.new(0, 4),
				BottomRightRadius = UDim.new(0, 4),
				TopLeftRadius = UDim.new(0, 4),
				TopRightRadius = UDim.new(0, 4),
			},
		},
	}
end

return KillsCoins
