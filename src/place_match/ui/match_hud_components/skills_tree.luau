--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local vide = require(replicated_storage.Packages.vide)
local ComponentTypes = require(script.Parent.component_types)
local ModifierConfig = require(replicated_storage.match.shared.configs.match_profile_config)
local SkillTypes = require(replicated_storage.match.shared.types.skill_types)

local create = vide.create
local indexes = vide.indexes

export type Props = {
	colors: ComponentTypes.ColorSources,
	skills: vide.Source<SkillTypes.OwnedSkills>,
}

local function createSkillTile(
	colors: ComponentTypes.ColorSources,
	skill: vide.Source<SkillTypes.OwnedSkill>,
	_: number,
	__: vide.Source<boolean>
): Frame
	local function getImage(): string
		return ModifierConfig[skill().key].image
	end

	local function getText(): string
		local currentSkill = skill()
		return string.format("%s  Lv. %d", ModifierConfig[currentSkill.key].name, currentSkill.level)
	end

	return create "Frame" {
		Name = "SkillTile",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 42),

		create "ImageLabel" {
			Name = "Background",
			BackgroundColor3 = colors.white,
			Image = "rbxassetid://106909274584862",
			ImageColor3 = colors.white,
			Size = UDim2.fromScale(1, 1),

			create "UIStroke" {
				Name = "UIStroke",
				Color = colors.purpleStroke,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.05,
			},

			create "UICorner" {
				Name = "UICorner",
				CornerRadius = UDim.new(0, 4),
			},
		},

		create "ImageLabel" {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = colors.white,
			BorderColor3 = colors.black,
			BorderSizePixel = 0,
			Image = getImage,
			ImageColor3 = colors.white,
			Position = UDim2.fromScale(0.05, 0.5),
			Size = UDim2.fromOffset(36, 36),
		},

		create "TextLabel" {
			Name = "Label",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/RobotoMono.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Italic
			),
			Position = UDim2.fromScale(0.3, 0.5),
			Size = UDim2.fromScale(0.65, 0.8),
			Text = getText,
			TextColor3 = colors.purple,
			TextScaled = true,
			ZIndex = 2,

			create "UIStroke" {
				Name = "UIStroke",
				Color = colors.black,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.002,
			},
		},
	}
end

local function SkillsTree(props: Props): Frame
	local function createIndexedSkillTile(
		skill: vide.Source<SkillTypes.OwnedSkill>,
		index: number,
		present: vide.Source<boolean>
	): Frame
		return createSkillTile(props.colors, skill, index, present)
	end

	return create "Frame" {
		Name = "Skill_Frame",
		AnchorPoint = Vector2.new(0.5, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.0756136, 0.375),
		Size = UDim2.new(0.142445, 0, 0, 0),

		create "UIListLayout" {
			Name = "UIListLayout",
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},

		indexes(props.skills, createIndexedSkillTile),
	}
end

return SkillsTree
