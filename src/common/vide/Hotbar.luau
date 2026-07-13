--!strict
--------------------------------------------------------------------------------
-- Hotbar.luau  (src/common/vide)
-- Reactive vide component for the hotbar inventory display.
-- Shows weapon slots with names and highlights the equipped slot.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide  = require(ReplicatedStorage.Packages.vide)
local theme = require(script.Parent.VideTheme)
local ui    = require(script.Parent.UiConfig)

local create = vide.create
local source = vide.source
local derive = vide.derive

--- Maps weapon names to their image asset IDs from UiConfig
local WEAPON_IMAGE_MAP = {}
for name, assetId in pairs(ui.images) do
	if string.match(assetId, "^rbxassetid://") and name ~= "MatchButton" and name ~= "ShopButton" 
		and name ~= "ClassShopButton" and name ~= "PlayButton" and name ~= "SilverIcon" 
		and name ~= "PlayerAvatar" and name ~= "PanelBackground" and name ~= "AccentBar" then
		WEAPON_IMAGE_MAP[name:lower()] = assetId
	end
end

export type HotbarProps = {
	-- Reactive sources for weapons and equipped slot
	weapons: () -> { string },
	equippedSlot: () -> number?,
	-- Size of the hotbar
	inventorySize: number,
}

--- Gets the image asset ID for a weapon name (returns nil if not found)
local function getWeaponImage(weaponName: string?): string?
	if not weaponName then
		return nil
	end
	return WEAPON_IMAGE_MAP[weaponName:lower()]
end

--- Creates a single hotbar slot
local function createSlot(index: number, weaponName: () -> string?, isEquipped: () -> boolean)
	return derive(function()
		local name = weaponName()
		local equipped = isEquipped()
		
		local backgroundColor = equipped and theme.ACCENT or Color3.fromRGB(0, 0, 0)
		local borderColor = equipped and theme.TEXT_HIGHLIGHT or theme.BORDER
		local textColor = name and theme.TEXT or theme.TEXT_DIM
		local weaponImage = getWeaponImage(name)
		
		return create "Frame" {
			Name = "Slot" .. tostring(index),
			Size = UDim2.new(0, 80, 0, 80),
			BackgroundColor3 = backgroundColor,
			BorderColor3 = borderColor,
			BorderSizePixel = equipped and 3 or 2,
			
			create "UICorner" {
				CornerRadius = UDim.new(0, 8),
			},
			
			create "ImageLabel" {
				Name = "WeaponIcon",
				Size = UDim2.new(0.95, 0, 0.95, 0),
				Position = UDim2.new(0.025, 0, 0.025, 0),
				BackgroundTransparency = 1,
				Image = weaponImage or "",
				ScaleType = Enum.ScaleType.Fit,
				
				create "UICorner" {
					CornerRadius = UDim.new(0, 6),
				},
			},
			
			create "TextLabel" {
				Name = "WeaponName",
				Size = UDim2.new(1, -8, 0.35, 0),
				Position = UDim2.new(0, 4, 0.65, 0),
				BackgroundTransparency = 1,
				Text = name or "",
				TextColor3 = textColor,
				TextScaled = true,
				Font = theme.FONT_BOLD,
				TextWrapped = true,
			},
		}
	end)
end

--- Creates the hotbar component
function createHotbar(props: HotbarProps)
	local slots = {}
	
	for i = 1, props.inventorySize do
		local weaponName = derive(function()
			local weapons = props.weapons()
			return weapons[i]
		end)
		
		local isEquipped = derive(function()
			return props.equippedSlot() == i
		end)
		
		table.insert(slots, createSlot(i, weaponName, isEquipped))
	end
	
	return create "Frame" {
		Name = "Hotbar",
		Size = UDim2.new(0, props.inventorySize * 85, 0, 85),
		Position = UDim2.new(0.5, -(props.inventorySize * 85) / 2, 1, -100),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		
		create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 5),
		},
		
		slots,
	}
end

return {
	createHotbar = createHotbar,
}
