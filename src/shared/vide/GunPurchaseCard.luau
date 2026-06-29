    --!strict
--------------------------------------------------------------------------------
-- GunPurchaseCard.luau  (src/shared/vide)
-- Reusable card component for the armory/shop UI.
--
-- Shows:
--   - Gun image (top)
--   - Gun name + stats table (middle)
--   - Buy button using DepressedButton (bottom)
--
-- Follows the vide component pattern.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide  = require(ReplicatedStorage.Packages.vide)
local theme = require(script.Parent.VideTheme)
local ui    = require(script.Parent.UiConfig)
local DepressedButton = require(script.Parent.DepressedButton)

local create = vide.create

export type GunStats = {
	damage: number,
	gold_cost: number,
	image: string,
	range: number,
	fireCooldown: number,
	magSize: number,
	max_ammo: number,
	reloadTime: number,
	isAutomatic: boolean,
	knockbackForce: number,
	tracer: {
		lifetime: number,
		thickness: number,
		color: Color3,
	},
	isShotgun: boolean?,
}

export type GunPurchaseCardProps = {
	parent: Instance,
	position: UDim2,
	size: UDim2,
	gunName: string,
	stats: GunStats,
	onBuy: () -> (),
}

--- Returns a human-readable fire-rate string (rounds per second).
local function fireRateStr(cooldown: number): string
	return string.format("%.1f rps", 1.0 / cooldown)
end

--- Creates a single gun-purchase card.
local function GunPurchaseCard(props: GunPurchaseCardProps)
	local card = create "Frame" {
		Name                   = "GunCard_" .. props.gunName,
		Parent                 = props.parent,
		Size                   = props.size,
		Position               = props.position,
		BackgroundColor3       = theme.BACKGROUND_LIGHT,
		BorderSizePixel        = 0,

		create "UICorner" {
			CornerRadius = theme.CORNER_RADIUS,
		},

		create "UIListLayout" {
			FillDirection     = Enum.FillDirection.Vertical,
			Padding           = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},

		-- ── Gun Image ────────────────────────────────────────────────
		create "ImageLabel" {
			Name                   = "GunImage",
			Size                   = UDim2.new(1, 0, 0, 140),
			BackgroundTransparency = 1,
			Image                  = props.stats.image or "rbxassetid://0",
			ScaleType              = Enum.ScaleType.Fit,

			create "UICorner" {
				CornerRadius = UDim.new(0, 8),
			},
		},

		-- ── Gun Name ────────────────────────────────────────────────
		create "TextLabel" {
			Name                   = "GunName",
			Size                   = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Text                   = props.gunName,
			TextColor3             = theme.TEXT_HIGHLIGHT,
			TextScaled             = true,
			Font                   = theme.FONT_BOLD,
			TextStrokeTransparency = 0.5,
		},

		-- ── Stats Table ─────────────────────────────────────────────
		create "Frame" {
			Name                   = "StatsTable",
			Size                   = UDim2.new(1, 0, 0, 130),
			BackgroundTransparency = 1,

			create "UIGridLayout" {
				CellSize    = UDim2.new(0.48, 0, 0, 18),
				CellPadding = UDim2.new(0, 4, 0, 2),
			},

			-- Damage
			create "TextLabel" {
				Size                   = UDim2.new(0.48, 0, 0, 18),
				BackgroundTransparency = 1,
				Text                   = "DMG: " .. tostring(props.stats.damage),
				TextColor3             = theme.TEXT_PRIMARY,
				TextSize               = 14,
				Font                   = theme.FONT_REGULAR,
				TextXAlignment         = Enum.TextXAlignment.Left,
			},

			-- Range
			create "TextLabel" {
				Size                   = UDim2.new(0.48, 0, 0, 18),
				BackgroundTransparency = 1,
				Text                   = "Range: " .. tostring(props.stats.range),
				TextColor3             = theme.TEXT_PRIMARY,
				TextSize               = 14,
				Font                   = theme.FONT_REGULAR,
				TextXAlignment         = Enum.TextXAlignment.Left,
			},

			-- Fire Rate
			create "TextLabel" {
				Size                   = UDim2.new(0.48, 0, 0, 18),
				BackgroundTransparency = 1,
				Text                   = "Fire: " .. fireRateStr(props.stats.fireCooldown),
				TextColor3             = theme.TEXT_PRIMARY,
				TextSize               = 14,
				Font                   = theme.FONT_REGULAR,
				TextXAlignment         = Enum.TextXAlignment.Left,
			},

			-- Magazine
			create "TextLabel" {
				Size                   = UDim2.new(0.48, 0, 0, 18),
				BackgroundTransparency = 1,
				Text                   = "Mag: " .. tostring(props.stats.magSize),
				TextColor3             = theme.TEXT_PRIMARY,
				TextSize               = 14,
				Font                   = theme.FONT_REGULAR,
				TextXAlignment         = Enum.TextXAlignment.Left,
			},

			-- Reload
			create "TextLabel" {
				Size                   = UDim2.new(0.48, 0, 0, 18),
				BackgroundTransparency = 1,
				Text                   = "Reload: " .. string.format("%.1fs", props.stats.reloadTime),
				TextColor3             = theme.TEXT_PRIMARY,
				TextSize               = 14,
				Font                   = theme.FONT_REGULAR,
				TextXAlignment         = Enum.TextXAlignment.Left,
			},

			-- Fire Mode
			create "TextLabel" {
				Size                   = UDim2.new(0.48, 0, 0, 18),
				BackgroundTransparency = 1,
				Text                   = "Mode: " .. (props.stats.isAutomatic and "Auto" or "Semi"),
				TextColor3             = theme.TEXT_PRIMARY,
				TextSize               = 14,
				Font                   = theme.FONT_REGULAR,
				TextXAlignment         = Enum.TextXAlignment.Left,
			},

			-- Knockback
			create "TextLabel" {
				Size                   = UDim2.new(0.48, 0, 0, 18),
				BackgroundTransparency = 1,
				Text                   = "KB: " .. tostring(props.stats.knockbackForce),
				TextColor3             = theme.TEXT_PRIMARY,
				TextSize               = 14,
				Font                   = theme.FONT_REGULAR,
				TextXAlignment         = Enum.TextXAlignment.Left,
			},

			-- Reserve Ammo
			create "TextLabel" {
				Size                   = UDim2.new(0.48, 0, 0, 18),
				BackgroundTransparency = 1,
				Text                   = "Reserve: " .. tostring(props.stats.max_ammo),
				TextColor3             = theme.TEXT_PRIMARY,
				TextSize               = 14,
				Font                   = theme.FONT_REGULAR,
				TextXAlignment         = Enum.TextXAlignment.Left,
			},
		},

		-- ── Gold Cost Label ────────────────────────────────────────
		create "TextLabel" {
			Name                   = "GoldCost",
			Size                   = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text                   = "🪙 " .. tostring(props.stats.gold_cost) .. " Gold",
			TextColor3             = theme.GOLD,
			TextScaled             = true,
			Font                   = theme.FONT_BOLD,
			TextStrokeTransparency = 0.5,
		},

		-- ── Buy Button (spacer so DepressedButton can sit at bottom) ─
		create "Frame" {
			Name                   = "BuyBtnSlot",
			Size                   = UDim2.new(0.6, 0, 0, 40),
			BackgroundTransparency = 1,
		},
	}

	-- DepressedButton sits inside the card's BuyBtnSlot
	local buySlot = card:FindFirstChild("BuyBtnSlot") :: Instance
	DepressedButton({
		parent   = buySlot,
		position = UDim2.new(0.5, 0, 0.5, 0),
		image    = ui.images.ShopButton,
		size     = UDim2.new(1, 0, 1, 0),
		onActivated = props.onBuy,
	})

	return card
end

return GunPurchaseCard
