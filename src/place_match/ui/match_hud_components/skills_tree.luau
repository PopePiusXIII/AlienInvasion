--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local vide = require(replicated_storage.Packages.vide)
local ComponentTypes = require(script.Parent.component_types)

local create = vide.create
local derive = vide.derive

export type Props = {
	colors: ComponentTypes.ColorSources,
	skills: vide.Source<{ ComponentTypes.Skill }>,
}

local SKILL_STYLES = {
	{
		backgroundPosition = UDim2.fromScale(0.0382203, 0.046932),
		iconPosition = UDim2.fromScale(0.102708, 0.0575705),
		iconSize = UDim2.fromScale(0.121697, 0.108505),
		textPosition = UDim2.fromScale(0.273602, 0.0451318),
	},
	{
		backgroundPosition = UDim2.fromScale(0.0382203, 0.217145),
		iconPosition = UDim2.fromScale(0.100983, 0.229569),
		iconSize = UDim2.fromScale(0.123423, 0.106447),
		textPosition = UDim2.fromScale(0.269553, 0.215345),
	},
	{
		backgroundPosition = UDim2.fromScale(0.0382203, 0.387357),
		iconPosition = UDim2.fromScale(0.100983, 0.406874),
		iconSize = UDim2.fromScale(0.123423, 0.106502),
		textPosition = UDim2.fromScale(0.269553, 0.389103),
	},
	{
		backgroundPosition = UDim2.fromScale(0.0382203, 0.55757),
		iconPosition = UDim2.fromScale(0.100983, 0.573541),
		iconSize = UDim2.fromScale(0.123423, 0.106502),
		textPosition = UDim2.fromScale(0.269553, 0.559316),
	},
	{
		backgroundPosition = UDim2.fromScale(0.0382203, 0.731329),
		iconPosition = UDim2.fromScale(0.0969343, 0.743753),
		iconSize = UDim2.fromScale(0.124459, 0.106906),
		textPosition = UDim2.fromScale(0.269553, 0.729529),
	},
}

local function SkillsTree(props: Props): Frame
	return create "Frame" {
		Name = "Skill_Frame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.0756136, 0.499794),
		Size = UDim2.fromScale(0.142445, 0.251786),

		derive(function()
			local children = {}
			local black = props.colors.black()
			local purple = props.colors.purple()
			local purpleStroke = props.colors.purpleStroke()
			local white = props.colors.white()

			for index, skill in ipairs(props.skills()) do
				local style = SKILL_STYLES[index]
				if not style then
					break
				end

				table.insert(children, create "Folder" {
					Name = "Skill_" .. tostring(index),

					create "ImageLabel" {
						Name = "Purple_Background_Image",
						BackgroundColor3 = white,
						Image = "rbxassetid://106909274584862",
						ImageColor3 = white,
						Position = style.backgroundPosition,
						Size = UDim2.fromScale(0.92328, 0.141846),

						create "UIStroke" {
							Name = "UIStroke",
							Color = purpleStroke,
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.05,
						},

						create "UICorner" {
							Name = "UICorner",
							BottomLeftRadius = UDim.new(0, 4),
							BottomRightRadius = UDim.new(0, 4),
							TopLeftRadius = UDim.new(0, 4),
							TopRightRadius = UDim.new(0, 4),
						},
					},

					create "ImageLabel" {
						Name = "Skill_" .. tostring(index) .. "_Icon",
						BackgroundColor3 = white,
						BorderColor3 = black,
						BorderSizePixel = 0,
						Image = skill.image,
						ImageColor3 = white,
						Position = style.iconPosition,
						Size = style.iconSize,
					},

					create "TextLabel" {
						Name = "Skill_" .. tostring(index) .. "_Text_Label",
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/RobotoMono.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Italic
						),
						Position = style.textPosition,
						Size = UDim2.fromScale(0.651961, 0.1401),
						Text = skill.name,
						TextColor3 = purple,
						TextScaled = true,
						ZIndex = 2,

						create "UIStroke" {
							Name = "UIStroke",
							Color = black,
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.002,
						},
					},
				})
			end

			return children
		end),
	}
end

return SkillsTree
