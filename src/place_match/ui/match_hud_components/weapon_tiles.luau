--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local vide = require(replicated_storage.Packages.vide)
local CombatConfig = require(replicated_storage.common.shared.configs.combat_config)
local ComponentTypes = require(script.Parent.component_types)

local create = vide.create
local indexes = vide.indexes

export type GunSlot = {
	name: string,
}

export type Props = {
	ammoColorByGun: vide.Source<{ [string]: Color3 }>,
	ammoTextByGun: vide.Source<{ [string]: string }>,
	colors: ComponentTypes.ColorSources,
	guns: vide.Source<{ GunSlot }>,
}

local function createGunTile(props: Props, gun: vide.Source<GunSlot>, _: number, __: vide.Source<boolean>): CanvasGroup
	local function getGunImage(): string
		local gunStats = CombatConfig.GUN_STATS[gun().name]
		assert(gunStats, string.format("Missing CombatConfig entry for gun '%s'", gun().name))
		return gunStats.image
	end

	local function getAmmoText(): string
		local gunName = gun().name
		local ammoText = props.ammoTextByGun()[gunName]
		if ammoText then
			return ammoText
		end

		local gunStats = CombatConfig.GUN_STATS[gunName]
		assert(gunStats, string.format("Missing CombatConfig entry for gun '%s'", gunName))
		return string.format("%d / %d", gunStats.magSize, gunStats.max_ammo)
	end

	local function getAmmoColor(): Color3
		local color = props.ammoColorByGun()[gun().name]
		assert(color, string.format("Missing ammo color for gun '%s'", gun().name))
		return color
	end

	return create "CanvasGroup" {
		Name = "WeaponTile",
		BackgroundColor3 = props.colors.white,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(100, 100),

		create "UICorner" {
			Name = "UICorner",
			BottomLeftRadius = UDim.new(0.1, 0),
			BottomRightRadius = UDim.new(0.1, 0),
			TopLeftRadius = UDim.new(0.1, 0),
			TopRightRadius = UDim.new(0.1, 0),
		},

		create "TextLabel" {
			Name = "Ammo",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json"),
			Position = UDim2.fromScale(0.5, 0.538128),
			Size = UDim2.fromOffset(200, 50),
			Text = getAmmoText,
			TextColor3 = getAmmoColor,
			TextSize = 14,
			ZIndex = 2,
		},

		create "ImageButton" {
			Name = "WeaponImage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = getGunImage,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.12, 1.12),
		},
	}
end

local function WeaponTiles(props: Props): Frame
	local function createIndexedGunTile(
		gun: vide.Source<GunSlot>,
		index: number,
		present: vide.Source<boolean>
	): CanvasGroup
		return createGunTile(props, gun, index, present)
	end

	return create "Frame" {
		Name = "Weapons",
		AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(0, 100),

		create "UIListLayout" {
			Name = "UIListLayout",
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},

		indexes(props.guns, createIndexedGunTile),
	}
end

return WeaponTiles
