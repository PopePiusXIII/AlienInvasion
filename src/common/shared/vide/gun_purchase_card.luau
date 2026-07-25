--!strict
--------------------------------------------------------------------------------
-- GunPurchaseCard.luau
-- Fixed alignment variant: Stats text centered cleanly inside columns.
-- Integrated with custom DepressedButton component (Fixed Parent reference).
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")

local vide  = require(replicated_storage.Packages.vide)
local theme = require(script.Parent.VideTheme)
local ui    = require(script.Parent.UiConfig)

-- Require the depressed button component
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
    parent: Instance?,
    position: UDim2,
    size: UDim2,
    gunName: string,
    stats: GunStats,
    onBuy: () -> (),
}

local function fireRateStr(cooldown: number): string
    return string.format("%.1f rps", 1.0 / cooldown)
end

local function GunPurchaseCard(props: GunPurchaseCardProps)
    -- Create the action group container ahead of time so we have a valid reference for the button parent
    local actionGroupFrame = create "Frame" {
        Name                   = "ActionGroup",
        Size                   = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1,

        create "UIListLayout" {
            FillDirection       = Enum.FillDirection.Vertical,
            Padding             = UDim.new(0, 6),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment   = Enum.VerticalAlignment.Center,
        },

        create "TextLabel" {
            Name                   = "GoldCost",
            Size                   = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Text                   = "🪙 " .. tostring(props.stats.gold_cost) .. " Gold",
            TextColor3             = theme.GOLD,
            TextSize               = 16,
            Font                   = theme.FONT_BOLD,
            TextXAlignment         = Enum.TextXAlignment.Center,
        },
    }

    -- Construct the button directly nested under our pre-declared actionGroupFrame container
	DepressedButton {
		parent       = actionGroupFrame,
		size         = UDim2.new(0.4, 0, 0, 32),
		position     = UDim2.new(0, 0, 0, 0),
		image        = ui.images.BuyButton,
		onActivated  = props.onBuy,
	}

    -- Build out the core master frame tree
    local cardFrame = create "Frame" {
        Name             = "GunCard_" .. props.gunName,
        Parent           = props.parent,
        Size             = props.size,
        Position         = props.position,
        BackgroundColor3 = theme.BACKGROUND_LIGHT,
        BorderSizePixel  = 0,

        create "UICorner" {
            CornerRadius = theme.CORNER_RADIUS,
        },

        create "UIPadding" {
            PaddingTop    = UDim.new(0, 16),
            PaddingBottom = UDim.new(0, 16),
            PaddingLeft   = UDim.new(0, 24),
            PaddingRight  = UDim.new(0, 24),
        },

        -- MASTER HORIZONTAL LAYOUT
        create "UIListLayout" {
            FillDirection       = Enum.FillDirection.Horizontal,
            Padding             = UDim.new(0, 32),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment   = Enum.VerticalAlignment.Center,
        },

        -- ── LEFT COLUMN: Text Content Stack ──
        create "Frame" {
            Name                   = "LeftColumn",
            Size                   = UDim2.new(0.55, 0, 1, 0),
            BackgroundTransparency = 1,

            create "UIListLayout" {
                FillDirection       = Enum.FillDirection.Vertical,
                Padding             = UDim.new(0, 14),
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                VerticalAlignment   = Enum.VerticalAlignment.Center,
            },

            -- 1. Gun Name
            create "TextLabel" {
                Name                   = "GunName",
                Size                   = UDim2.new(1, 0, 0, 32),
                BackgroundTransparency = 1,
                Text                   = props.gunName,
                TextColor3             = theme.TEXT_HIGHLIGHT,
                TextSize               = 26,
                Font                   = theme.FONT_BOLD,
                TextXAlignment         = Enum.TextXAlignment.Center,
            },

            -- 2. Stats Block (Two side-by-side columns)
            create "Frame" {
                Name                   = "StatsContainer",
                Size                   = UDim2.new(1, 0, 0, 90), 
                BackgroundTransparency = 1,

                create "UIListLayout" {
                    FillDirection       = Enum.FillDirection.Horizontal,
                    Padding             = UDim.new(0, 24),
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment   = Enum.VerticalAlignment.Center,
                },

                -- Stat Sub-Column 1
                create "Frame" {
                    Name                   = "StatColumn1",
                    Size                   = UDim2.new(0.45, 0, 1, 0),
                    BackgroundTransparency = 1,

                    create "UIListLayout" {
                        FillDirection       = Enum.FillDirection.Vertical,
                        Padding             = UDim.new(0, 4),
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        VerticalAlignment   = Enum.VerticalAlignment.Center,
                    },

                    create "TextLabel" {
                        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
                        Text = "DMG: " .. tostring(props.stats.damage),
                        TextColor3 = theme.TEXT_PRIMARY, TextSize = 15, Font = theme.FONT_REGULAR,
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                    create "TextLabel" {
                        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
                        Text = "Fire: " .. fireRateStr(props.stats.fireCooldown),
                        TextColor3 = theme.TEXT_PRIMARY, TextSize = 15, Font = theme.FONT_REGULAR,
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                    create "TextLabel" {
                        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
                        Text = "Reload: " .. string.format("%.1fs", props.stats.reloadTime),
                        TextColor3 = theme.TEXT_PRIMARY, TextSize = 15, Font = theme.FONT_REGULAR,
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                    create "TextLabel" {
                        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
                        Text = "KB: " .. tostring(props.stats.knockbackForce),
                        TextColor3 = theme.TEXT_PRIMARY, TextSize = 15, Font = theme.FONT_REGULAR,
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                },

                -- Stat Sub-Column 2
                create "Frame" {
                    Name                   = "StatColumn2",
                    Size                   = UDim2.new(0.45, 0, 1, 0),
                    BackgroundTransparency = 1,

                    create "UIListLayout" {
                        FillDirection       = Enum.FillDirection.Vertical,
                        Padding             = UDim.new(0, 4),
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        VerticalAlignment   = Enum.VerticalAlignment.Center,
                    },

                    create "TextLabel" {
                        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
                        Text = "Range: " .. tostring(props.stats.range),
                        TextColor3 = theme.TEXT_PRIMARY, TextSize = 15, Font = theme.FONT_REGULAR,
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                    create "TextLabel" {
                        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
                        Text = "Mag: " .. tostring(props.stats.magSize),
                        TextColor3 = theme.TEXT_PRIMARY, TextSize = 15, Font = theme.FONT_REGULAR,
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                    create "TextLabel" {
                        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
                        Text = "Mode: " .. (props.stats.isAutomatic and "Auto" or "Semi"),
                        TextColor3 = theme.TEXT_PRIMARY, TextSize = 15, Font = theme.FONT_REGULAR,
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                    create "TextLabel" {
                        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
                        Text = "Reserve: " .. tostring(props.stats.max_ammo),
                        TextColor3 = theme.TEXT_PRIMARY, TextSize = 15, Font = theme.FONT_REGULAR,
                        TextXAlignment = Enum.TextXAlignment.Center,
                    },
                },
            },

            -- Mount the pre-built action frame directly down the left layout column stack
            actionGroupFrame,
        },

        -- ── RIGHT COLUMN: Weapon Image Display Card ──
        create "ImageLabel" {
            Name                   = "GunImage",
            Size                   = UDim2.new(0.4, 0, 1, 0),
            BackgroundTransparency = 1,
            Image                  = props.stats.image,
            ScaleType              = Enum.ScaleType.Fit,

            create "UICorner" {
                CornerRadius = UDim.new(0, 8),
            },
        },
    }

    return cardFrame
end

return GunPurchaseCard