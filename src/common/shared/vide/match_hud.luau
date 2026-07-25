--!strict
--------------------------------------------------------------------------------
-- MatchHUD.luau  (src/common/vide)
-- Reactive vide component for the in-game HUD during a match.
-- Based on the "Roblox Zombie Game UI" Figma design — dark tactical/sci-fi theme.
--
-- Renders:
--   - Top bar: Kills + coins (left), wave info (center), timer + area (right)
--   - Kill feed (top-right)
--   - Perks list (left side, vertically centered)
--   - Bottom-left: Minimap + HP/Armor stat bars
--   - Bottom-center: Active weapon display + hotbar slots
--   - Bottom-right: Objectives + XP bar
--   - Crosshair (center screen)
--   - Wave alert overlay (full-screen, shown on wave start)
--
-- All state is reactive via vide signals — update a signal and the UI
-- re-renders automatically. No manual DOM manipulation needed.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")

local vide  = require(replicated_storage.Packages.vide)
local theme = require(replicated_storage.common.shared.vide.vide_theme)

local create = vide.create
local source = vide.source
local derive = vide.derive
local mount  = vide.mount

-- ── Tactical color palette (matches Figma dark theme) ─────────────────────────

local C = {}
C.BACKGROUND       = Color3.fromRGB(8, 8, 15)           -- Deep space bg
C.CARD             = Color3.fromRGB(3, 0, 59)          -- Figma dark blue panel bg
C.CARD_ALPHA       = 0.8                                -- Panel transparency (80% opaque)
C.BORDER           = Color3.fromRGB(107, 100, 237)     -- Purple border (Figma accent)
C.ACCENT           = Color3.fromRGB(107, 100, 237)     -- Purple accent
C.DESTRUCTIVE      = Color3.fromRGB(255, 0, 0)         -- Red for danger/alerts (Figma skull red)
C.FOREGROUND       = Color3.fromRGB(255, 255, 255)     -- White text
C.MUTED            = Color3.fromRGB(107, 100, 237)     -- Purple muted labels (Figma text color)
C.HEALTH_GREEN     = C.ACCENT                          -- HP bar (purple like Figma)
C.HEALTH_YELLOW    = Color3.fromRGB(255, 170, 0)       -- Low HP warning
C.HEALTH_RED       = Color3.fromRGB(255, 34, 34)       -- Critical HP
C.ARMOR_BLUE       = C.ACCENT                          -- Armor bar also purple in Figma
C.GOLD             = theme.GOLD                         -- Gold currency
C.SILVER           = theme.SILVER                       -- Silver/coins

local FONT_MONO    = Enum.Font.Code                      -- Monospace (closest to JetBrains Mono)
local FONT_BOLD    = Enum.Font.GothamBold                -- Bold for headings
local FONT_REGULAR = Enum.Font.Gotham                    -- Regular body text

local CORNER       = UDim.new(0, 6)                     -- Figma panel corner radius
local SLOT_CORNER  = UDim.new(0, 6)                     -- Hotbar slot rounding

-- ── Types ─────────────────────────────────────────────────────────────────────

export type MatchHUDProps = {
    parentGui: Instance?,
    inventorySize: number?,
}

export type KillFeedEntry = {
    player: string,
    method: string,
}

export type Perk = {
    name: string,
    active: boolean,
}

export type Objective = {
    text: string,
    done: boolean,
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

--- Create a semi-transparent panel frame (matches Figma card style)
--- Dark blue bg @ 80% opacity, purple border, corner radius 6, drop shadow
local function createPanel(name: string, size: UDim2, position: UDim2?, children: any?)
    local attrs: { [string]: any } = {
        Name                   = name,
        Size                   = size,
        BackgroundColor3       = C.CARD,
        BackgroundTransparency = 1 - C.CARD_ALPHA,
        BorderColor3           = C.BORDER,
        BorderSizePixel        = 2, -- Figma stroke weight = 2
    }
    if position then
        attrs.Position = position
    end
    return create "Frame" {
        attrs,
        create "UICorner" { CornerRadius = CORNER },
        -- DropShadow: Color=black, Offset=(0,4), Radius=4 (Figma effect)
        children,
    }
end

--- Create a stat bar (HP / Armor style with tick marks)
--- When used inside a derive(), this reads the closures directly.
local function _createStatBar(label: () -> string, valuePct: () -> number, color: () -> Color3)
    return derive(function()
        local pct   = math.clamp(valuePct(), 0, 1)
        local col   = color()

        return create "Frame" {
            Name = "StatBar",
            Size = UDim2.new(1, 0, 0, 24),

            -- Label row
            create "Frame" {
                Name = "LabelRow",
                Size = UDim2.new(1, 0, 0, 12),
                BackgroundTransparency = 1,

                create "TextLabel" {
                    Size          = UDim2.new(0.6, 0, 1, 0),
                    Position      = UDim2.new(0, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Text          = label(),
                    TextColor3    = C.MUTED,
                    TextSize      = 9,
                    Font          = FONT_MONO,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped   = true,
                },

                create "TextLabel" {
                    Size          = UDim2.new(0.4, 0, 1, 0),
                    Position      = UDim2.new(0.6, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Text          = tostring(math.floor(pct * 100)) .. "/100",
                    TextColor3    = col,
                    TextSize      = 9,
                    Font          = FONT_MONO,
                    TextXAlignment = Enum.TextXAlignment.Right,
                },
            },

            -- Bar track
            create "Frame" {
                Name = "Track",
                Size = UDim2.new(1, 0, 0, 10),
                Position = UDim2.new(0, 0, 0, 14),
                BackgroundColor3 = Color3.fromRGB(30, 30, 45),
                BorderColor3     = C.BORDER,
                BorderSizePixel  = 1,

                -- Tick marks (every 10%)
                create "UIListLayout" {
                    FillDirection    = Enum.FillDirection.Horizontal,
                    Padding          = UDim.new(0, 0),
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                },

                create "Frame" { Size = UDim2.new(0.1, 0, 1, 0), BackgroundTransparency = 0.6, BackgroundColor3 = C.BACKGROUND },
                create "Frame" { Size = UDim2.new(0.1, 0, 1, 0), BackgroundTransparency = 0.6, BackgroundColor3 = C.BACKGROUND },
                create "Frame" { Size = UDim2.new(0.1, 0, 1, 0), BackgroundTransparency = 0.6, BackgroundColor3 = C.BACKGROUND },
                create "Frame" { Size = UDim2.new(0.1, 0, 1, 0), BackgroundTransparency = 0.6, BackgroundColor3 = C.BACKGROUND },
                create "Frame" { Size = UDim2.new(0.1, 0, 1, 0), BackgroundTransparency = 0.6, BackgroundColor3 = C.BACKGROUND },
                create "Frame" { Size = UDim2.new(0.1, 0, 1, 0), BackgroundTransparency = 0.6, BackgroundColor3 = C.BACKGROUND },
                create "Frame" { Size = UDim2.new(0.1, 0, 1, 0), BackgroundTransparency = 0.6, BackgroundColor3 = C.BACKGROUND },
                create "Frame" { Size = UDim2.new(0.1, 0, 1, 0), BackgroundTransparency = 0.6, BackgroundColor3 = C.BACKGROUND },
                create "Frame" { Size = UDim2.new(0.1, 0, 1, 0), BackgroundTransparency = 0.6, BackgroundColor3 = C.BACKGROUND },

                -- Fill
                create "Frame" {
                    Name = "Fill",
                    Size = UDim2.new(pct, 0, 1, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    BackgroundColor3 = col,
                    BackgroundTransparency = pct < 0.25 and 0.5 or 0.7,
                },
            },
        }
    end)
end

--- Create a single kill feed entry
local function _createKillFeedEntry(playerText: () -> string, methodText: () -> string)
    return derive(function()
        return create "Frame" {
            Name = "KillEntry",
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundColor3 = C.BACKGROUND,
            BackgroundTransparency = 0.4,
            BorderColor3 = C.DESTRUCTIVE,
            BorderSizePixel = 2,

            create "UICorner" { CornerRadius = CORNER },

            create "TextLabel" {
                Size          = UDim2.new(0.55, 0, 1, 0),
                Position      = UDim2.new(0.03, 0, 0, 0),
                BackgroundTransparency = 1,
                Text          = playerText(),
                TextColor3    = C.FOREGROUND,
                TextSize      = 9,
                Font          = FONT_MONO,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped   = true,
            },

            create "TextLabel" {
                Size          = UDim2.new(0.1, 0, 1, 0),
                Position      = UDim2.new(0.58, 0, 0, 0),
                BackgroundTransparency = 1,
                Text          = ">",
                TextColor3    = C.MUTED,
                TextSize      = 9,
                Font          = FONT_MONO,
            },

            create "TextLabel" {
                Size          = UDim2.new(0.3, 0, 1, 0),
                Position      = UDim2.new(0.7, 0, 0, 0),
                BackgroundTransparency = 1,
                Text          = methodText(),
                TextColor3    = C.ACCENT,
                TextSize      = 9,
                Font          = FONT_MONO,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
        }
    end)
end

--- Create a perk badge
local function _createPerkBadge(nameText: () -> string, isActive: () -> boolean)
    return derive(function()
        local active = isActive()
        return create "Frame" {
            Name = "PerkBadge",
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundColor3 = active and C.ACCENT or C.CARD,
            BackgroundTransparency = active and 0.95 or 0.7,
            BorderColor3     = active and C.ACCENT or C.BORDER,
            BorderSizePixel  = 1,

            create "UICorner" { CornerRadius = CORNER },

            create "TextLabel" {
                Size          = UDim2.new(1, -8, 1, 0),
                Position      = UDim2.new(0, 4, 0, 0),
                BackgroundTransparency = 1,
                Text          = nameText(),
                TextColor3    = active and C.ACCENT or C.MUTED,
                TextSize      = 9,
                Font          = FONT_MONO,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
        }
    end)
end

--- Create a minimap placeholder (grid + dots for players/enemies)
local function createMinimap()
    return create "Frame" {
        Name = "Minimap",
        Size = UDim2.new(0, 100, 0, 100),
        BackgroundColor3 = C.CARD,
        BorderColor3     = C.BORDER,
        BorderSizePixel  = 1,

        create "UICorner" { CornerRadius = CORNER },

        -- Grid lines (horizontal)
        create "Frame" { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0.25, 0), BackgroundTransparency = 0.8, BackgroundColor3 = C.ACCENT },
        create "Frame" { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0.5, 0),  BackgroundTransparency = 0.8, BackgroundColor3 = C.ACCENT },
        create "Frame" { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0.75, 0), BackgroundTransparency = 0.8, BackgroundColor3 = C.ACCENT },

        -- Grid lines (vertical)
        create "Frame" { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(0.25, 0, 0, 0), BackgroundTransparency = 0.8, BackgroundColor3 = C.ACCENT },
        create "Frame" { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(0.5, 0, 0, 0),  BackgroundTransparency = 0.8, BackgroundColor3 = C.ACCENT },
        create "Frame" { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(0.75, 0, 0, 0), BackgroundTransparency = 0.8, BackgroundColor3 = C.ACCENT },

        -- "You" dot (center-ish)
        create "Frame" {
            Size = UDim2.new(0, 6, 0, 6),
            Position = UDim2.new(0.35, -3, 0.55, -3),
            BackgroundColor3 = C.ACCENT,
            BorderSizePixel = 0,
            create "UICorner" { CornerRadius = UDim.new(1, 0) },
        },

        -- Enemy dots
        create "Frame" { Size = UDim2.new(0, 4, 0, 4), Position = UDim2.new(0.7, -2, 0.3, -2), BackgroundColor3 = C.DESTRUCTIVE, BorderSizePixel = 0, create "UICorner" { CornerRadius = UDim.new(1, 0) } },
        create "Frame" { Size = UDim2.new(0, 4, 0, 4), Position = UDim2.new(0.2, -2, 0.2, -2), BackgroundColor3 = C.DESTRUCTIVE, BorderSizePixel = 0, create "UICorner" { CornerRadius = UDim.new(1, 0) } },
        create "Frame" { Size = UDim2.new(0, 4, 0, 4), Position = UDim2.new(0.8, -2, 0.7, -2), BackgroundColor3 = C.DESTRUCTIVE, BorderSizePixel = 0, create "UICorner" { CornerRadius = UDim.new(1, 0) } },

        -- Area label
        create "TextLabel" {
            Size          = UDim2.new(1, 0, 0, 10),
            Position      = UDim2.new(0, 0, 1, -10),
            BackgroundTransparency = 1,
            Text          = "AREA-7",
            TextColor3    = C.MUTED,
            TextSize      = 8,
            Font          = FONT_MONO,
        },
    }
end

--- Create the crosshair
local function createCrosshair()
    return create "Frame" {
        Name = "Crosshair",
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(0.5, -12, 0.5, -12),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,

        -- Top arm
        create "Frame" { Size = UDim2.new(0, 1, 0, 8), Position = UDim2.new(0.5, -0.5, 0, 0), BackgroundColor3 = C.ACCENT, BackgroundTransparency = 0.2 },
        -- Bottom arm
        create "Frame" { Size = UDim2.new(0, 1, 0, 8), Position = UDim2.new(0.5, -0.5, 1, 0), BackgroundColor3 = C.ACCENT, BackgroundTransparency = 0.2 },
        -- Left arm
        create "Frame" { Size = UDim2.new(0, 8, 0, 1), Position = UDim2.new(0, 0, 0.5, -0.5), BackgroundColor3 = C.ACCENT, BackgroundTransparency = 0.2 },
        -- Right arm
        create "Frame" { Size = UDim2.new(0, 8, 0, 1), Position = UDim2.new(1, 0, 0.5, -0.5), BackgroundColor3 = C.ACCENT, BackgroundTransparency = 0.2 },
        -- Center dot
        create "Frame" { Size = UDim2.new(0, 4, 0, 4), Position = UDim2.new(0.5, -2, 0.5, -2), BackgroundColor3 = C.ACCENT, BackgroundTransparency = 0.4, create "UICorner" { CornerRadius = UDim.new(1, 0) } },
    }
end

--- Create an objective checkbox row
local function _createObjectiveRow(text: () -> string, done: () -> boolean)
    return derive(function()
        local completed = done()
        return create "Frame" {
            Name = "ObjRow",
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,

            -- Checkbox
            create "Frame" {
                Size = UDim2.new(0, 10, 0, 10),
                Position = UDim2.new(0, 0, 0.5, -5),
                BackgroundColor3 = completed and C.ACCENT or C.BACKGROUND,
                BackgroundTransparency = completed and 0.8 or 0.5,
                BorderColor3 = completed and C.ACCENT or C.MUTED,
                BorderSizePixel = 1,
                create "UICorner" { CornerRadius = UDim.new(0, 2) },

                -- Check fill
                create "Frame" {
                    Visible = completed,
                    Size = UDim2.new(0, 4, 0, 4),
                    Position = UDim2.new(0.5, -2, 0.5, -2),
                    BackgroundColor3 = C.ACCENT,
                },
            },

            -- Text
            create "TextLabel" {
                Size          = UDim2.new(1, -14, 1, 0),
                Position      = UDim2.new(0, 16, 0, 0),
                BackgroundTransparency = 1,
                Text          = text(),
                TextColor3    = completed and C.MUTED or C.FOREGROUND,
                TextSize      = 9,
                Font          = FONT_REGULAR,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped   = true,
            },
        }
    end)
end

--- Create the XP progress bar
local function _createXPBar(xpCurrent: () -> number, xpMax: () -> number)
    return derive(function()
        local pct = math.clamp(xpCurrent() / math.max(xpMax(), 1), 0, 1)
        return create "Frame" {
            Name = "XPBar",
            Size = UDim2.new(1, 0, 0, 20),

            create "TextLabel" {
                Size          = UDim2.new(1, 0, 0, 10),
                BackgroundTransparency = 1,
                Text          = tostring(xpCurrent()) .. " / " .. tostring(xpMax()),
                TextColor3    = C.MUTED,
                TextSize      = 9,
                Font          = FONT_MONO,
            },

            -- Track
            create "Frame" {
                Size = UDim2.new(1, 0, 0, 6),
                Position = UDim2.new(0, 0, 0, 14),
                BackgroundColor3 = Color3.fromRGB(30, 30, 45),
                BorderColor3     = C.BORDER,
                BorderSizePixel  = 1,

                -- Fill
                create "Frame" {
                    Size = UDim2.new(pct, 0, 1, 0),
                    BackgroundColor3 = C.ACCENT,
                    BackgroundTransparency = 0.4,
                },
            },
        }
    end)
end

--- Create a hotbar slot for a weapon
local function _createWeaponSlot(index: number, weaponName: () -> string?, isEquipped: () -> boolean, onClick: () -> ())
    return derive(function()
        local name     = weaponName()
        local equipped = isEquipped()
        local isEmpty  = not name or name == ""

        return create "TextButton" {
            Name = "WeaponSlot" .. tostring(index),
            Size = UDim2.new(0, 56, 0, 64),
            BackgroundColor3 = equipped and C.ACCENT or C.CARD,
            BackgroundTransparency = equipped and 0.9 or 0.2,
            BorderColor3     = equipped and C.ACCENT or C.BORDER,
            BorderSizePixel  = 1,
            Text = "",

            create "UICorner" { CornerRadius = SLOT_CORNER },

            -- Top accent line when active
            create "Frame" {
                Visible = equipped,
                Size = UDim2.new(1, 0, 0, 2),
                Position = UDim2.new(0, 0, 0, 0),
                BackgroundColor3 = C.ACCENT,
            },

            -- Weapon name / icon area
            create "TextLabel" {
                Size          = UDim2.new(1, -8, 0.6, 0),
                Position      = UDim2.new(0, 4, 0.1, 0),
                BackgroundTransparency = 1,
                Text          = isEmpty and "—" or (name or ""),
                TextColor3    = isEmpty and C.MUTED or C.FOREGROUND,
                TextSize      = 10,
                Font          = FONT_BOLD,
                TextWrapped   = true,
            },

            -- Ammo display (bottom)
            create "TextLabel" {
                Name = "AmmoText",
                Size = UDim2.new(1, -8, 0.3, 0),
                Position = UDim2.new(0, 4, 0.7, 0),
                BackgroundTransparency = 1,
                Text          = "",
                TextColor3    = C.MUTED,
                TextSize      = 8,
                Font          = FONT_MONO,
            },
        }
    end)
end

-- ── Main HUD Factory ──────────────────────────────────────────────────────────

function createMatchHUD(props: MatchHUDProps): ({
    -- Legacy controls (kept for backward compatibility)
    setWaveText:     (string) -> (),
    clearWaveText:   () -> (),
    setAmmoText:     (string, Color3) -> (),
    setSilverAmount: (number) -> (),
    setGoldAmount:   (number) -> (),
    setInventory:    (weapons: { string }, equippedSlot: number?) -> (),
    -- New Figma-style controls
    setWaveNumber:       (number) -> (),
    setZombiesRemaining: (number) -> (),
    setKills:            (number) -> (),
    setCoins:            (number) -> (),
    setTimerSeconds:     (number) -> (),
    setAreaName:         (string) -> (),
    setHP:               (number, number) -> (),          -- current, max
    setArmor:            (number, number) -> (),          -- current, max
    addKillFeedEntry:    (player: string, method: string) -> (),
    clearKillFeed:       () -> (),
    setPerks:            ({ { name: string, active: boolean } }) -> (),
    setObjectives:       ({ { text: string, done: boolean } }) -> (),
    setXP:               (number, number) -> (),          -- current, max
    setActiveWeaponAmmo: (current: number, maxMag: number) -> (),
    setSlotAmmo:         (slotIndex: number, current: number, maxMag: number) -> (),
    onSlotClick:         ((index: number) -> ()) -> (),   -- Register slot click handler
}, () -> ())

    -- ── Reactive signals ──────────────────────────────────────────────

    -- Top bar
    local waveNumber        = source(1)
    local zombiesRemaining  = source(0)
    local kills             = source(0)
    local coins             = source(0)
    local timerSeconds      = source(60)
    local areaName          = source("AREA-7")

    -- Player stats
    local hpCurrent         = source(100)
    local hpMax             = source(100)
    local armorCurrent      = source(50)
    local armorMax          = source(100)

    -- Kill feed (last 5 entries)
    local killFeedEntries   = source({} :: { KillFeedEntry })

    -- Perks
    local perks             = source({} :: { Perk })

    -- Objectives
    local objectives        = source({} :: { Objective })

    -- XP
    local xpCurrent         = source(0)
    local xpMax             = source(5000)

    -- Inventory / hotbar
    local inventoryWeapons  = source({})
    local inventoryEquippedSlot = source(1 :: number?)
    local inventorySize     = props.inventorySize or 5

    -- Ammo per slot: { slotIndex -> { current, max } }
    local slotAmmoData      = source({} :: { [number]: { current: number, max: number } })

    -- Active weapon ammo display
    local activeWeaponAmmo  = source({ current = 0, max = 0 })

    -- Wave alert overlay
    local waveAlertVisible  = source(false)
    local waveAlertNumber   = source(1)

    -- Slot click callback (stored imperatively)
    local _slotClickHandler: ((number) -> ())? = nil

    -- ── Legacy signal aliases (for backward compat) ───────────────────
    local waveText     = source("")
    local ammoText     = source("")
    local ammoColor    = source(Color3.new(1, 1, 1))
    local silverAmount = source(0)
    local goldAmount   = source(0)

    -- ── ScreenGui ─────────────────────────────────────────────────────
    local screenGui: Instance
    if props.parentGui then
        screenGui = props.parentGui
    else
        screenGui = create "ScreenGui" {
            Name           = "AlienInvasionHud",
            ResetOnSpawn   = false,
            IgnoreGuiInset = true,
            Parent         = Players.LocalPlayer.PlayerGui,
        }
    end

    -- ── Reactive render tree ──────────────────────────────────────────

    local function renderHUD()
        return {
            -- Scanline overlay (subtle CRT effect - very light, doesn't block input)
            create "Frame" {
                Name = "Scanlines",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 0.995, -- Only 0.5% opaque, barely visible
            },

            -- ── TOP BAR ───────────────────────────────────────────────
            create "Frame" {
                Name = "TopBar",
                Size = UDim2.new(1, 0, 0, 48),
                Position = UDim2.new(0, 0, 0, 8),
                BackgroundTransparency = 1,

                -- Left panel: Kills + Coins
                derive(function()
                    return createPanel("LeftPanel", UDim2.new(0, 200, 0, 36), UDim2.new(0, 16, 0, 6), {
                        create "UIListLayout" {
                            FillDirection = Enum.FillDirection.Horizontal,
                            Padding = UDim.new(0, 4),
                            HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        },

                        -- Kills
                        create "Frame" {
                            Size = UDim2.new(0.5, -12, 1, 0),
                            BackgroundTransparency = 1,
                            create "UIListLayout" {
                                FillDirection = Enum.FillDirection.Horizontal,
                                Padding = UDim.new(0, 6),
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                            },
                            create "TextLabel" {
                                Size = UDim2.new(0.4, 0, 0.5, 0),
                                Position = UDim2.new(0, 0, 0, 0),
                                BackgroundTransparency = 1,
                                Text = "KILLS",
                                TextColor3 = C.MUTED,
                                TextSize = 9,
                                Font = FONT_MONO,
                            },
                            create "TextLabel" {
                                Size = UDim2.new(0.5, 0, 0.7, 0),
                                Position = UDim2.new(0.4, 0, 0.15, 0),
                                BackgroundTransparency = 1,
                                Text = tostring(kills()),
                                TextColor3 = C.FOREGROUND,
                                TextSize = 16,
                                Font = FONT_BOLD,
                            },
                        },

                        -- Skull icon (Figma kills panel has red skull)
                        create "TextLabel" {
                            Size = UDim2.new(0, 16, 0, 18),
                            Position = UDim2.new(0, 4, 0.5, -9),
                            BackgroundTransparency = 1,
                            Text = "\u{2620}",
                            TextColor3 = C.DESTRUCTIVE,
                            TextSize = 16,
                            Font = FONT_MONO,
                        },

                        -- Divider
                        create "Frame" {
                            Size = UDim2.new(0, 1, 0.7, 0),
                            Position = UDim2.new(0.5, 0, 0.15, 0),
                            BackgroundColor3 = C.BORDER,
                        },

                        -- Coins
                        create "Frame" {
                            Size = UDim2.new(0.5, -12, 1, 0),
                            BackgroundTransparency = 1,
                            create "UIListLayout" {
                                FillDirection = Enum.FillDirection.Horizontal,
                                Padding = UDim.new(0, 6),
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                            },
                            create "TextLabel" {
                                Size = UDim2.new(0.4, 0, 0.5, 0),
                                Position = UDim2.new(0, 0, 0, 0),
                                BackgroundTransparency = 1,
                                Text = "COINS",
                                TextColor3 = C.MUTED,
                                TextSize = 9,
                                Font = FONT_MONO,
                            },
                            create "TextLabel" {
                                Size = UDim2.new(0.5, 0, 0.7, 0),
                                Position = UDim2.new(0.4, 0, 0.15, 0),
                                BackgroundTransparency = 1,
                                Text = tostring(coins()),
                                TextColor3 = C.ACCENT,
                                TextSize = 16,
                                Font = FONT_BOLD,
                            },
                        },
                    })
                end),

                -- Center panel: Wave info
                derive(function()
                    local w = waveNumber()
                    local z = zombiesRemaining()
                    local timerLow = timerSeconds() < 10

                    return createPanel("WavePanel", UDim2.new(0, 240, 0, 44), UDim2.new(0.5, -120, 0, 4), {
                        -- "WAVE" label with warning dots
                        create "TextLabel" {
                            Size = UDim2.new(1, 0, 0, 12),
                            Position = UDim2.new(0, 0, 0, 0),
                            BackgroundTransparency = 1,
                            Text = "\u{2620}  WAVE  \u{2620}", -- Skull icons like Figma timer panel
                            TextColor3 = C.DESTRUCTIVE,
                            TextSize = 9,
                            Font = FONT_MONO,
                        },

                        create "TextLabel" {
                            Size = UDim2.new(1, 0, 0, 20),
                            Position = UDim2.new(0, 0, 0, 12),
                            BackgroundTransparency = 1,
                            Text = tostring(w),
                            TextColor3 = C.FOREGROUND,
                            TextSize = 22,
                            Font = FONT_BOLD,
                        },

                        -- Zombies remaining + timer
                        create "TextLabel" {
                            Size = UDim2.new(0.5, 0, 0, 10),
                            Position = UDim2.new(0, 0, 1, -10),
                            BackgroundTransparency = 1,
                            Text = "\u{25CF} " .. tostring(z) .. " REMAINING",
                            TextColor3 = C.DESTRUCTIVE,
                            TextSize = 8,
                            Font = FONT_MONO,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        },

                        create "TextLabel" {
                            Size = UDim2.new(0.5, 0, 0, 10),
                            Position = UDim2.new(0.5, 0, 1, -10),
                            BackgroundTransparency = 1,
                            Text = "TIME " .. string.format("%02d:%02d", math.floor(timerSeconds() / 60), timerSeconds() % 60),
                            TextColor3 = timerLow and C.DESTRUCTIVE or C.FOREGROUND,
                            TextSize = 9,
                            Font = FONT_MONO,
                            TextXAlignment = Enum.TextXAlignment.Right,
                        },
                    })
                end),

                -- Right panel: Timer + Area
                derive(function()
                    return createPanel("RightPanel", UDim2.new(0, 140, 0, 36), UDim2.new(1, -16, 0, 6), {
                        create "UIListLayout" {
                            FillDirection = Enum.FillDirection.Horizontal,
                            Padding = UDim.new(0, 8),
                            HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        },

                        create "TextLabel" {
                            Size = UDim2.new(0.5, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Text = "AREA",
                            TextColor3 = C.MUTED,
                            TextSize = 9,
                            Font = FONT_MONO,
                        },
                        create "TextLabel" {
                            Size = UDim2.new(0.5, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Text = areaName(),
                            TextColor3 = C.FOREGROUND,
                            TextSize = 12,
                            Font = FONT_BOLD,
                        },
                    })
                end),
            },

            -- ── KILL FEED (top-right, below top bar) ──────────────────
            derive(function()
                local entries = killFeedEntries()
                if #entries == 0 then return nil end

                local children = {}
                for i = 1, math.min(#entries, 5) do
                    local e = entries[i]
                    table.insert(children, create "Frame" {
                        Name = "KillEntry",
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundColor3 = C.BACKGROUND,
                        BackgroundTransparency = 0.4,
                        BorderColor3 = C.DESTRUCTIVE,
                        BorderSizePixel = 2,

                        create "UICorner" { CornerRadius = CORNER },

                        create "TextLabel" {
                            Size          = UDim2.new(0.55, 0, 1, 0),
                            Position      = UDim2.new(0.03, 0, 0, 0),
                            BackgroundTransparency = 1,
                            Text          = e.player,
                            TextColor3    = C.FOREGROUND,
                            TextSize      = 9,
                            Font          = FONT_MONO,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextWrapped   = true,
                        },

                        create "TextLabel" {
                            Size          = UDim2.new(0.1, 0, 1, 0),
                            Position      = UDim2.new(0.58, 0, 0, 0),
                            BackgroundTransparency = 1,
                            Text          = ">",
                            TextColor3    = C.MUTED,
                            TextSize      = 9,
                            Font          = FONT_MONO,
                        },

                        create "TextLabel" {
                            Size          = UDim2.new(0.3, 0, 1, 0),
                            Position      = UDim2.new(0.7, 0, 0, 0),
                            BackgroundTransparency = 1,
                            Text          = e.method,
                            TextColor3    = C.ACCENT,
                            TextSize      = 9,
                            Font          = FONT_MONO,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        },
                    })
                end

                return create "Frame" {
                    Name = "KillFeed",
                    Size = UDim2.new(0, 220, 0, #entries * 20),
                    Position = UDim2.new(1, -20, 0, 60),
                    BackgroundTransparency = 1,

                    create "UIListLayout" {
                        FillDirection = Enum.FillDirection.Vertical,
                        Padding = UDim.new(0, 4),
                        VerticalAlignment = Enum.VerticalAlignment.Top,
                    },

                    table.unpack(children),
                }
            end),

            -- ── PERKS (left side, vertically centered) ────────────────
            derive(function()
                local p = perks()
                if #p == 0 then return nil end

                local children = {}
                for _, perk in ipairs(p) do
                    table.insert(children, create "Frame" {
                        Name = "PerkBadge",
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundColor3 = perk.active and C.ACCENT or C.CARD,
                        BackgroundTransparency = perk.active and 0.95 or 0.7,
                        BorderColor3     = perk.active and C.ACCENT or C.BORDER,
                        BorderSizePixel  = 1,

                        create "UICorner" { CornerRadius = CORNER },

                        create "TextLabel" {
                            Size          = UDim2.new(1, -8, 1, 0),
                            Position      = UDim2.new(0, 4, 0, 0),
                            BackgroundTransparency = 1,
                            Text          = perk.name,
                            TextColor3    = perk.active and C.ACCENT or C.MUTED,
                            TextSize      = 9,
                            Font          = FONT_MONO,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        },
                    })
                end

                return createPanel("PerksPanel", UDim2.new(0, 120, 0, #p * 22), UDim2.new(0, 16, 0.5, -(#p * 11)), children)
            end),

            -- ── BOTTOM HUD ────────────────────────────────────────────
            create "Frame" {
                Name = "BottomHud",
                Size = UDim2.new(1, 0, 0, 140),
                Position = UDim2.new(0, 0, 1, -140),
                BackgroundTransparency = 1,

                -- Bottom-left: Minimap + HP/Armor
                create "Frame" {
                    Name = "BottomLeft",
                    Size = UDim2.new(0, 130, 1, 0),
                    Position = UDim2.new(0, 16, 0, 0),
                    BackgroundTransparency = 1,

                    -- Minimap
                    createMinimap(),

                    -- Stats panel (below minimap) — single derive, no nesting
                    derive(function()
                        local hpPct   = hpCurrent() / math.max(hpMax(), 1)
                        local armorPct = armorCurrent() / math.max(armorMax(), 1)

                        local hpColor
                        if hpPct < 0.25 then hpColor = C.HEALTH_RED
                        elseif hpPct < 0.5 then hpColor = C.HEALTH_YELLOW
                        else hpColor = C.HEALTH_GREEN end

                        return createPanel("StatsPanel", UDim2.new(0, 110, 0, 60), UDim2.new(0, 10, 0, 110), {
                            create "UIListLayout" {
                                FillDirection = Enum.FillDirection.Vertical,
                                Padding = UDim.new(0, 4),
                            },

                            -- HP bar (inline, no nested derive)
                            create "Frame" {
                                Name = "HPBar",
                                Size = UDim2.new(1, 0, 0, 24),
                                create "Frame" {
                                    Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1,
                                    create "TextLabel" {
                                        Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1,
                                        Text = "HP", TextColor3 = C.MUTED, TextSize = 9, Font = FONT_MONO,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                    },
                                    create "TextLabel" {
                                        Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0.6, 0, 0, 0), BackgroundTransparency = 1,
                                        Text = tostring(math.floor(hpPct * 100)) .. "/100", TextColor3 = hpColor, TextSize = 9, Font = FONT_MONO,
                                        TextXAlignment = Enum.TextXAlignment.Right,
                                    },
                                },
                                create "Frame" {
                                    Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 0, 14),
                                    BackgroundColor3 = Color3.fromRGB(30, 30, 45), BorderColor3 = C.BORDER, BorderSizePixel = 1,
                                    create "Frame" {
                                        Size = UDim2.new(hpPct, 0, 1, 0),
                                        BackgroundColor3 = hpColor, BackgroundTransparency = hpPct < 0.25 and 0.5 or 0.7,
                                    },
                                },
                            },

                            -- Armor bar (inline)
                            create "Frame" {
                                Name = "ArmorBar",
                                Size = UDim2.new(1, 0, 0, 24),
                                create "Frame" {
                                    Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1,
                                    create "TextLabel" {
                                        Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1,
                                        Text = "ARMOR", TextColor3 = C.MUTED, TextSize = 9, Font = FONT_MONO,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                    },
                                    create "TextLabel" {
                                        Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0.6, 0, 0, 0), BackgroundTransparency = 1,
                                        Text = tostring(math.floor(armorPct * 100)) .. "/100", TextColor3 = C.ARMOR_BLUE, TextSize = 9, Font = FONT_MONO,
                                        TextXAlignment = Enum.TextXAlignment.Right,
                                    },
                                },
                                create "Frame" {
                                    Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 0, 14),
                                    BackgroundColor3 = Color3.fromRGB(30, 30, 45), BorderColor3 = C.BORDER, BorderSizePixel = 1,
                                    create "Frame" {
                                        Size = UDim2.new(armorPct, 0, 1, 0),
                                        BackgroundColor3 = C.ARMOR_BLUE, BackgroundTransparency = 0.7,
                                    },
                                },
                            },
                        })
                    end),
                },

                -- Bottom-center: Active weapon + hotbar slots — single derive, no nesting
                derive(function()
                    local weapons    = inventoryWeapons()
                    local equipped   = inventoryEquippedSlot() or 1
                    local ammoData   = slotAmmoData()
                    local activeAmmo = activeWeaponAmmo()

                    -- Find active weapon name
                    local activeWeapon = weapons[equipped]
                    local activeWeaponName = activeWeapon and activeWeapon.name or ""

                    local children = {}

                    -- Active weapon display panel
                    table.insert(children, createPanel("ActiveWeapon", UDim2.new(0, 180, 0, 36), UDim2.new(0.5, -90, 0, 0), {
                        create "UIListLayout" {
                            FillDirection = Enum.FillDirection.Horizontal,
                            Padding = UDim.new(0, 10),
                            HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        },

                        -- Weapon name
                        create "TextLabel" {
                            Size = UDim2.new(0.6, 0, 0.6, 0),
                            Position = UDim2.new(0, 8, 0.2, 0),
                            BackgroundTransparency = 1,
                            Text = activeWeaponName or "—",
                            TextColor3 = C.FOREGROUND,
                            TextSize = 13,
                            Font = FONT_BOLD,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        },

                        -- Ammo count
                        create "TextLabel" {
                            Size = UDim2.new(0.4, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Text = tostring(activeAmmo.current) .. " / " .. tostring(activeAmmo.max),
                            TextColor3 = C.ACCENT,
                            TextSize = 12,
                            Font = FONT_MONO,
                            TextXAlignment = Enum.TextXAlignment.Right,
                        },
                    }))

                    -- Weapon slots row — build inline, no nested derive
                    local slotChildren = {}
                    for i = 1, inventorySize do
                        local weapon    = weapons[i]
                        local weaponName = weapon and weapon.name or ""
                        local isEquipped = (equipped == i)
                        local sAmmo     = ammoData[i]

                        table.insert(slotChildren, create "TextButton" {
                            Name = "Slot" .. tostring(i),
                            Size = UDim2.new(0, 56, 0, 64),
                            BackgroundColor3 = isEquipped and C.ACCENT or C.CARD,
                            BackgroundTransparency = isEquipped and 0.9 or 0.2,
                            BorderColor3     = isEquipped and C.ACCENT or C.BORDER,
                            BorderSizePixel  = 1,
                            Text = "",

                            create "UICorner" { CornerRadius = SLOT_CORNER },

                            -- Top accent line
                            create "Frame" {
                                Visible = isEquipped,
                                Size = UDim2.new(1, 0, 0, 2),
                                BackgroundColor3 = C.ACCENT,
                            },

                            -- Weapon name
                            create "TextLabel" {
                                Size = UDim2.new(1, -8, 0.6, 0),
                                Position = UDim2.new(0, 4, 0.1, 0),
                                BackgroundTransparency = 1,
                                Text = weaponName == "" and "—" or weaponName,
                                TextColor3 = weaponName == "" and C.MUTED or C.FOREGROUND,
                                TextSize = 10,
                                Font = FONT_BOLD,
                                TextWrapped = true,
                            },

                            -- Ammo text
                            create "TextLabel" {
                                Size = UDim2.new(1, -8, 0.3, 0),
                                Position = UDim2.new(0, 4, 0.7, 0),
                                BackgroundTransparency = 1,
                                Text = sAmmo and (tostring(sAmmo.current) .. "/" .. tostring(sAmmo.max)) or "",
                                TextColor3 = C.MUTED,
                                TextSize = 8,
                                Font = FONT_MONO,
                            },
                        })
                    end

                    table.insert(children, create "Frame" {
                        Name = "WeaponSlots",
                        Size = UDim2.new(0, inventorySize * 61, 0, 64),
                        Position = UDim2.new(0.5, -(inventorySize * 61) / 2, 1, -72),
                        BackgroundTransparency = 1,

                        create "UIListLayout" {
                            FillDirection = Enum.FillDirection.Horizontal,
                            Padding = UDim.new(0, 5),
                            HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        },

                        table.unpack(slotChildren),
                    })

                    return create "Frame" {
                        Name = "BottomCenter",
                        Size = UDim2.new(1, -280, 1, 0),
                        Position = UDim2.new(0, 140, 0, 0),
                        BackgroundTransparency = 1,

                        create "UIListLayout" {
                            FillDirection = Enum.FillDirection.Vertical,
                            Padding = UDim.new(0, 6),
                            VerticalAlignment = Enum.VerticalAlignment.Bottom,
                        },

                        table.unpack(children),
                    }
                end),

                -- Bottom-right: Objectives + XP — single derive, no nesting
                derive(function()
                    local objs = objectives()
                    local xpPct = math.clamp(xpCurrent() / math.max(xpMax(), 1), 0, 1)

                    -- Build objective rows inline (no nested derive)
                    local objRows = {}
                    for _, obj in ipairs(objs) do
                        table.insert(objRows, create "Frame" {
                            Name = "ObjRow",
                            Size = UDim2.new(1, 0, 0, 14),
                            BackgroundTransparency = 1,

                            -- Checkbox
                            create "Frame" {
                                Size = UDim2.new(0, 10, 0, 10),
                                Position = UDim2.new(0, 0, 0.5, -5),
                                BackgroundColor3 = obj.done and C.ACCENT or C.BACKGROUND,
                                BackgroundTransparency = obj.done and 0.8 or 0.5,
                                BorderColor3 = obj.done and C.ACCENT or C.MUTED,
                                BorderSizePixel = 1,
                                create "UICorner" { CornerRadius = UDim.new(0, 2) },

                                create "Frame" {
                                    Visible = obj.done,
                                    Size = UDim2.new(0, 4, 0, 4),
                                    Position = UDim2.new(0.5, -2, 0.5, -2),
                                    BackgroundColor3 = C.ACCENT,
                                },
                            },

                            -- Text
                            create "TextLabel" {
                                Size = UDim2.new(1, -14, 1, 0),
                                Position = UDim2.new(0, 16, 0, 0),
                                BackgroundTransparency = 1,
                                Text = obj.text,
                                TextColor3 = obj.done and C.MUTED or C.FOREGROUND,
                                TextSize = 9,
                                Font = FONT_REGULAR,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextWrapped = true,
                            },
                        })
                    end

                    return createPanel("ObjectivesPanel", UDim2.new(0, 180, 0, 120), UDim2.new(1, -20, 0, 10), {
                        -- Header
                        create "TextLabel" {
                            Size = UDim2.new(1, 0, 0, 12),
                            Position = UDim2.new(0, 0, 0, 4),
                            BackgroundTransparency = 1,
                            Text = "OBJECTIVES",
                            TextColor3 = C.MUTED,
                            TextSize = 9,
                            Font = FONT_MONO,
                        },

                        -- Objective rows
                        create "ScrollingFrame" {
                            Name = "ObjList",
                            Size = UDim2.new(1, -8, 0, 50),
                            Position = UDim2.new(0, 4, 0, 18),
                            BackgroundTransparency = 1,
                            ScrollBarThickness = 0,

                            create "UIListLayout" {
                                FillDirection = Enum.FillDirection.Vertical,
                                Padding = UDim.new(0, 2),
                            },

                            table.unpack(objRows),
                        },

                        -- XP bar
                        create "Frame" {
                            Name = "XPSection",
                            Size = UDim2.new(1, -8, 0, 24),
                            Position = UDim2.new(0, 4, 1, -24),

                            create "TextLabel" {
                                Size = UDim2.new(0.5, 0, 0, 10),
                                BackgroundTransparency = 1,
                                Text = "XP",
                                TextColor3 = C.MUTED,
                                TextSize = 9,
                                Font = FONT_MONO,
                            },

                            create "TextLabel" {
                                Size = UDim2.new(0.5, 0, 0, 10),
                                Position = UDim2.new(0.5, 0, 0, 0),
                                BackgroundTransparency = 1,
                                Text = tostring(xpCurrent()) .. " / " .. tostring(xpMax()),
                                TextColor3 = C.ACCENT,
                                TextSize = 9,
                                Font = FONT_MONO,
                                TextXAlignment = Enum.TextXAlignment.Right,
                            },

                            -- XP track
                            create "Frame" {
                                Size = UDim2.new(1, 0, 0, 5),
                                Position = UDim2.new(0, 0, 0, 14),
                                BackgroundColor3 = Color3.fromRGB(30, 30, 45),
                                BorderColor3     = C.BORDER,
                                BorderSizePixel  = 1,

                                create "Frame" {
                                    Size = UDim2.new(xpPct, 0, 1, 0),
                                    BackgroundColor3 = C.ACCENT,
                                    BackgroundTransparency = 0.4,
                                },
                            },
                        },
                    })
                end),
            },

            -- ── CROSSHAIR ─────────────────────────────────────────────
            createCrosshair(),

            -- ── WAVE ALERT OVERLAY ────────────────────────────────────
            -- Matches Figma: "INCOMING" red italic top, large wave name with white stroke,
            -- "SURVIVE OR DIE" subtitle bottom, frosted glass panel
            derive(function()
                if not waveAlertVisible() then return nil end

                return create "Frame" {
                    Name = "WaveAlert",
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    ZIndex = 100,

                    -- Frosted glass center panel (Figma: bg blur 14px, dark blue @ 12% opacity)
                    create "Frame" {
                        Name = "AlertPanel",
                        Size = UDim2.new(0.5, 0, 0, 173),
                        Position = UDim2.new(0.25, 0, 0.4, 0),
                        BackgroundColor3 = C.CARD,
                        BackgroundTransparency = 0.88, -- Figma: 12% opaque
                        BorderColor3 = C.BORDER,
                        BorderSizePixel = 1,
                        create "UICorner" { CornerRadius = CORNER },
                        -- BlurEffect: ScissorTest=true, Size=14 (Figma background blur)

                        -- Skull icons top (Figma: red skull pair)
                        create "TextLabel" {
                            Size = UDim2.new(1, 0, 0, 30),
                            Position = UDim2.new(0, 0, 0, 0),
                            BackgroundTransparency = 1,
                            Text = "\u{2620}                              \u{2620}",
                            TextColor3 = C.DESTRUCTIVE,
                            TextSize = 24,
                            Font = FONT_MONO,
                        },

                        -- "INCOMING" label (Figma: red, italic, 32px)
                        create "TextLabel" {
                            Size = UDim2.new(1, 0, 0, 32),
                            Position = UDim2.new(0, 0, 0, 28),
                            BackgroundTransparency = 1,
                            Text = "INCOMING",
                            TextColor3 = C.DESTRUCTIVE,
                            TextSize = 32,
                            Font = FONT_MONO,
                        },

                        -- Large wave name (Figma: black fill + white stroke, extra bold italic, 64px)
                        create "TextLabel" {
                            Size = UDim2.new(1, 0, 0, 70),
                            Position = UDim2.new(0, 0, 0, 60),
                            BackgroundTransparency = 1,
                            Text = "WAVE " .. tostring(waveAlertNumber()),
                            TextColor3 = C.BACKGROUND,
                            TextStrokeTransparency = 0, -- White outline like Figma
                            TextSize = 64,
                            Font = FONT_BOLD,
                        },

                        -- "SURVIVE OR DIE" subtitle (Figma: purple, extra bold italic, 20px)
                        create "TextLabel" {
                            Size = UDim2.new(1, 0, 0, 20),
                            Position = UDim2.new(0, 0, 0, 130),
                            BackgroundTransparency = 1,
                            Text = "SURVIVE OR DIE",
                            TextColor3 = C.ACCENT,
                            TextSize = 20,
                            Font = FONT_MONO,
                        },
                    },
                }
            end),

            -- ── LEGACY: Silver/Gold labels (kept for backward compat) ─
            derive(function()
                local amount = silverAmount()
                if amount == 0 then return nil end
                return create "TextLabel" {
                    Name = "SilverLabel",
                    Size = UDim2.new(0.24, 0, 0.06, 0),
                    Position = UDim2.new(0.02, 0, 0.88, 0),
                    BackgroundTransparency = 1,
                    TextColor3 = C.SILVER,
                    TextScaled = true,
                    Font = FONT_BOLD,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = "SILVER: " .. tostring(math.max(0, math.floor(amount))),
                }
            end),

            derive(function()
                local amount = goldAmount()
                if amount == 0 then return nil end
                return create "TextLabel" {
                    Name = "GoldLabel",
                    Size = UDim2.new(0.24, 0, 0.06, 0),
                    Position = UDim2.new(0.02, 0, 0.81, 0),
                    BackgroundTransparency = 1,
                    TextColor3 = C.GOLD,
                    TextScaled = true,
                    Font = FONT_BOLD,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = "GOLD: " .. tostring(math.max(0, math.floor(amount))),
                }
            end),
        }
    end

    -- ── Mount ─────────────────────────────────────────────────────────
    local unmount = mount(renderHUD, screenGui)

    -- ── Controls table ────────────────────────────────────────────────
    local controls = {
        -- Legacy
        setWaveText = function(text: string) waveText(text) end,
        clearWaveText = function() waveText("") end,
        setAmmoText = function(text: string, color: Color3)
            ammoText(text)
            ammoColor(color)
        end,
        setSilverAmount = function(amount: number) silverAmount(amount) end,
        setGoldAmount   = function(amount: number) goldAmount(amount) end,
        setInventory = function(weapons: { string }, equippedSlot: number?)
            inventoryWeapons(weapons)
            inventoryEquippedSlot(equippedSlot)
        end,

        -- New Figma-style controls
        setWaveNumber = function(n: number) waveNumber(n) end,
        setZombiesRemaining = function(n: number) zombiesRemaining(n) end,
        setKills = function(n: number) kills(n) end,
        setCoins = function(n: number) coins(n) end,
        setTimerSeconds = function(n: number) timerSeconds(n) end,
        setAreaName = function(name: string) areaName(name) end,

        setHP = function(current: number, max: number)
            hpCurrent(current)
            hpMax(max)
        end,
        setArmor = function(current: number, max: number)
            armorCurrent(current)
            armorMax(max)
        end,

        addKillFeedEntry = function(player: string, method: string)
            local feed = killFeedEntries()
            table.insert(feed, 1, { player = player, method = method })
            if #feed > 5 then table.remove(feed) end
            killFeedEntries(feed)
        end,
        clearKillFeed = function() killFeedEntries({}) end,

        setPerks = function(list: { Perk }) perks(list) end,
        setObjectives = function(list: { Objective }) objectives(list) end,

        setXP = function(current: number, max: number)
            xpCurrent(current)
            xpMax(max)
        end,

        setActiveWeaponAmmo = function(current: number, maxMag: number)
            activeWeaponAmmo({ current = current, max = maxMag })
        end,

        setSlotAmmo = function(slotIndex: number, current: number, maxMag: number)
            local data = slotAmmoData()
            data[slotIndex] = { current = current, max = maxMag }
            slotAmmoData(data)
        end,

        onSlotClick = function(handler: (number) -> ())
            _slotClickHandler = handler
        end,
    }

    return controls, unmount
end

return {
    createMatchHUD = createMatchHUD,
}
