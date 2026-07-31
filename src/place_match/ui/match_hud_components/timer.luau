--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local vide = require(replicated_storage.Packages.vide)
local ComponentTypes = require(script.Parent.component_types)

local create = vide.create
local derive = vide.derive

export type Props = {
	colors: ComponentTypes.ColorSources,
	seconds: vide.Source<number>,
}

local function Timer(props: Props): Frame
	local timerText = derive(function()
		local seconds = math.max(0, math.floor(props.seconds()))
		return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
	end)

	return create "Frame" {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = props.colors.white,
		BorderColor3 = props.colors.black,
		BorderSizePixel = 0,
		Position = UDim2.new(0.498798, 0, 0.0635531, -10),
		Size = UDim2.fromScale(0.130317, 0.0825394),

		create "UIAspectRatioConstraint" {
			Name = "UIAspectRatioConstraint",
			AspectRatio = 4.34,
		},

		create "ImageLabel" {
			Name = "ImageLabel",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Image = "rbxassetid://83025760843264",
			ImageColor3 = props.colors.white,
			Position = UDim2.fromScale(0.863551, 0.259735),
			Size = UDim2.fromScale(0.0592586, 0.257182),
			ZIndex = 2,
		},

		create "TextLabel" {
			Name = "23",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/RobotoMono.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Italic
			),
			Position = UDim2.fromScale(0.5, 0.744823),
			Size = UDim2.fromScale(0.199943, 0.510354),
			Text = timerText,
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
			Image = "rbxassetid://83025760843264",
			ImageColor3 = props.colors.white,
			Position = UDim2.fromScale(0.045263, 0.259735),
			Size = UDim2.fromScale(0.0592586, 0.257182),
			ZIndex = 2,
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

		create "TextLabel" {
			Name = "KILLS",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/RobotoMono.json",
				Enum.FontWeight.Regular,
				Enum.FontStyle.Italic
			),
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.5, 0.256229),
			Size = UDim2.fromScale(0.216467, 0.495768),
			Text = "TIME",
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
	}
end

return Timer
