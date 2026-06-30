--!strict
--------------------------------------------------------------------------------
-- Hotbar.luau  (src/shared/vide)
-- Reactive vide component for the hotbar inventory display.
-- Shows weapon slots with names and highlights the equipped slot.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide  = require(ReplicatedStorage.Packages.vide)
local theme = require(script.Parent.VideTheme)

local create = vide.create
local source = vide.source
local derive = vide.derive

export type HotbarProps = {
	-- Reactive sources for weapons and equipped slot
	weapons: () -> { string },
	equippedSlot: () -> number?,
	-- Size of the hotbar
	inventorySize: number,
}

--- Creates a single hotbar slot
local function createSlot(index: number, weaponName: () -> string?, isEquipped: () -> boolean)
	return derive(function()
		local name = weaponName()
		local equipped = isEquipped()
		
		local backgroundColor = equipped and theme.ACCENT or theme.BACKGROUND_DARK
		local borderColor = equipped and theme.TEXT_HIGHLIGHT or theme.BORDER
		local textColor = name and theme.TEXT or theme.TEXT_DIM
		
		return create "Frame" {
			Name = "Slot" .. tostring(index),
			Size = UDim2.new(0, 80, 0, 80),
			BackgroundColor3 = backgroundColor,
			BorderColor3 = borderColor,
			BorderSizePixel = equipped and 3 or 2,
			
			create "TextLabel" {
				Name = "SlotNumber",
				Size = UDim2.new(0, 20, 0, 20),
				Position = UDim2.new(0, 2, 0, 2),
				BackgroundTransparency = 1,
				Text = tostring(index),
				TextColor3 = theme.TEXT_DIM,
				TextSize = 14,
				Font = theme.FONT_REGULAR,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			},
			
			create "TextLabel" {
				Name = "WeaponName",
				Size = UDim2.new(1, -8, 1, -8),
				Position = UDim2.new(0, 4, 0, 4),
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
