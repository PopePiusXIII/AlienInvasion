--!strict
--------------------------------------------------------------------------------
-- Armory.luau  (src/shared/vide)
-- Armory popup: a 4-column, 3-row grid of DepressedButtons.
-- Each column is a weapon category; rows are progression tiers.
--   Col 1: Assault Rifles
--   Col 2: LMGs
--   Col 3: Pistols
--   Col 4: Shotguns
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide  = require(ReplicatedStorage.Packages.vide)
local theme = require(script.Parent.VideTheme)
local ui    = require(script.Parent.UiConfig)
local DepressedButton = require(script.Parent.DepressedButton)

local create = vide.create

-- ── Weapon data (4 columns × 3 rows) ────────────────────────────────────────
type WeaponEntry = {
    name: string,
    column: number,       -- 1-4
    row: number,          -- 1-3 (progression tier)
    price: number,
    owned: boolean,
    image: string,
}

local weapons: { WeaponEntry } = {
    -- Column 1: Assault Rifles
    { name = "M82",      column = 1, row = 1, price = 0,   owned = true,  image = ui.images.ShopButton },
    { name = "AK-47",    column = 1, row = 2, price = 60,  owned = false, image = ui.images.Mp5 },
    { name = "SCAR-H",   column = 1, row = 3, price = 100, owned = false, image = ui.images.Scar},

    -- Column 2: LMGs
    { name = "M60",      column = 2, row = 1, price = 80,  owned = false, image = ui.images.ShopButton },
    { name = "M240B",    column = 2, row = 2, price = 100, owned = false, image = ui.images.ShopButton },
    { name = "MG3",      column = 2, row = 3, price = 120, owned = false, image = ui.images.ShopButton },

    -- Column 3: Pistols
    { name = "Deagle",   column = 3, row = 1, price = 0,   owned = true,  image = ui.images.ShopButton },
    { name = "Glock",    column = 3, row = 2, price = 30,  owned = false, image = ui.images.ShopButton },
    { name = "USP",      column = 3, row = 3, price = 40,  owned = false, image = ui.images.ShopButton },

    -- Column 4: Shotguns
    { name = "BushMaster", column = 4, row = 1, price = 0,   owned = true,  image = ui.images.ShopButton },
    { name = "SPAS-12",  column = 4, row = 2, price = 70,  owned = false, image = ui.images.ShopButton },
    { name = "AA-12",    column = 4, row = 3, price = 90,  owned = false, image = ui.images.ShopButton },
}

-- ── Layout constants ──────────────────────────────────────────────────────────
local COLS     = 4
local GAP      = 0.03   -- gap between buttons (fraction of panel)
local MARGIN   = 0.03   -- outer margin (fraction of panel)

-- Category label names per column
local categoryNames = {
    "ASSAULT RIFLES",
    "LMGs",
    "PISTOLS",
    "SHOTGUNS",
}

--- Returns the X position for a given column index (0-based).
local function colX(colIndex: number): number
    local btnW = (1 - 2 * MARGIN - (COLS - 1) * GAP) / COLS
    return MARGIN + colIndex * (btnW + GAP)
end

--- Creates the armory popup panel.
--- Returns a toggle function so the caller just calls it on click.
function createArmoryHUD(screenGui: Instance): () -> ()
    local armoryPanel = create "Frame" {
        Name                   = "ArmoryPanel",
        Parent                 = screenGui,
        Size                 = UDim2.new(0.62, 0, 0.52, 0),
        Position             = UDim2.new(0.19, 0, 0.24, 0),
        BackgroundColor3     = theme.BACKGROUND,
        BackgroundTransparency = 0.1,
        BorderSizePixel      = 0,
        Visible              = false,

        create "UICorner" {
            CornerRadius = theme.CORNER_RADIUS,
        },

        

        -- Red accent bar at top
        create "Frame" {
            Name              = "Accent",
            Size             = UDim2.new(1, 0, 0.04, 0),
            BackgroundColor3 = theme.ACCENT,
            BorderSizePixel  = 0,

            create "UICorner" {
                CornerRadius = theme.CORNER_RADIUS,
            },
        },

        -- Title
        create "TextLabel" {
            Name                   = "Title",
            Size                 = UDim2.new(0.5, 0, 0.08, 0),
            Position             = UDim2.new(0.02, 0, 0.05, 0),
            BackgroundTransparency = 1,
            TextColor3           = theme.TEXT_PRIMARY,
            TextScaled           = true,
            Font                 = theme.FONT_BOLD,
            TextXAlignment       = Enum.TextXAlignment.Left,
            Text                 = "ARMORY",
        },

        -- Close button
        create "TextButton" {
            Name                   = "CloseBtn",
            Size                 = UDim2.new(0.06, 0, 0.06, 0),
            Position             = UDim2.new(0.92, 0, 0.05, 0),
            BackgroundColor3     = Color3.fromRGB(90, 35, 35),
            TextColor3           = Color3.new(1, 1, 1),
            Text                 = "✕",
            TextScaled           = true,
            Font                 = theme.FONT_BOLD,
            BorderSizePixel      = 0,
            AutoButtonColor      = true,

            create "UICorner" {
                CornerRadius = theme.BUTTON_CORNER,
            },
        },
    }

    -- Wire close button
    local closeBtn = armoryPanel:FindFirstChild("CloseBtn")
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(function()
            armoryPanel.Visible = false
        end)
    end

    -- Build category labels above each column (static, outside scroll area)
    -- for col = 1, COLS do
    --     create "TextLabel" {
    --         Name                   = "Label_Col" .. col,
    --         Parent                 = armoryPanel,
    --         Size                 = UDim2.new(0.22, 0, 0.1, 0),
    --         Position             = UDim2.new(colX(col - 1) + 0.01, 0, 0.12, 0),
    --         BackgroundTransparency = 1,
    --         TextColor3           = theme.TEXT_SECONDARY,
    --         TextScaled           = true,
    --         Font                 = theme.FONT_REGULAR,
    --         TextXAlignment       = Enum.TextXAlignment.Center,
    --         Text                 = categoryNames[col] or "",
    --     }
    -- end

    -- ScrollingFrame container for the weapon grid
    local scrollFrame = create "ScrollingFrame" {
        Name                   = "WeaponGrid",
        Parent                 = armoryPanel,
        Size                 = UDim2.new(0.96, 0, 0.85, 0),
        Position             = UDim2.new(0.02, 0, 0.15, 0),
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        CanvasSize           = UDim2.new(0, 0, 2, 0),   -- grows vertically as needed
        ScrollBarThickness   = 6,
        ClipsDescendants     = true,
        ScrollBarImageColor3 = theme.ACCENT,

        -- Grid layout: 4 columns, auto-rows
        create "UIGridLayout" {
            SortOrder      = Enum.SortOrder.LayoutOrder,
            CellSize       = UDim2.new(0.22, 0, 0.22, 0),
            CellPadding    = UDim2.new(GAP, 0, GAP, 0),
            FillDirection  = Enum.FillDirection.Horizontal,
        },

        -- Click sound (must be child of scrollFrame so DepressedButton can find it)
        create "Sound" {
            Name     = "ShopClick",
            SoundId  = ui.sounds.Click,
            Volume   = ui.button.clickVolume,
        },
    }

    -- Loop through weapons and create DepressedButtons inside the scroll frame
    for _, weapon in ipairs(weapons) do
        DepressedButton({
            parent   = scrollFrame,
            position = UDim2.new(0.5, 0, 0.5, 0),   -- UIGridLayout handles positioning
            image    = weapon.image,
            size     = UDim2.new(1, 0, 1, 0),       -- fills grid cell
            hoverSoundId = ui.sounds.HoverSoundId,
            onActivated = function()
                -- TODO: purchase / select weapon
            end,
        })
    end

    return function()
        armoryPanel.Visible = not armoryPanel.Visible
    end
end

return {
    createArmoryHUD = createArmoryHUD,
}
