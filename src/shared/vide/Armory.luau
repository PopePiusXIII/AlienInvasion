--!strict
--------------------------------------------------------------------------------
-- Armory.luau  (src/shared/vide)
-- Armory popup: a grid of weapon icons.
-- Clicking an icon opens a breakout detail panel with GunPurchaseCard.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide  = require(ReplicatedStorage.Packages.vide)
local theme = require(script.Parent.VideTheme)
local ui    = require(script.Parent.UiConfig)
local DepressedButton = require(script.Parent.DepressedButton)
local GunPurchaseCard = require(script.Parent.GunPurchaseCard)

local create = vide.create

-- ── Weapon grid data ────────────────────────────────────────────────────────
-- `configKey` maps to CombatConfig.GUN_STATS[key].  If nil, the card won't
-- render full stats (placeholder / coming-soon).
type WeaponEntry = {
    label: string,          -- display name on grid icon
    configKey: string?,     -- key into CombatConfig.GUN_STATS (nil = placeholder)
    image: string,
}

local weapons: { WeaponEntry } = {
    -- Assault Rifles
    { label = "M82",      configKey = "M82",      image = ui.images.ShopButton },
    { label = "MP5",      configKey = "MP5",      image = ui.images.Mp5 },
    { label = "SCAR",     configKey = "SCAR",     image = ui.images.Scar },

    -- LMGs
    { label = "M60",      configKey = "M60",      image = ui.images.ShopButton },
    { label = "MG42",     configKey = "MG42",     image = ui.images.ShopButton },
    { label = "M240B",    configKey = "M240B",    image = ui.images.ShopButton },

    -- Pistols
    { label = "Deagle",   configKey = "Deagle",   image = ui.images.ShopButton },
    { label = "HandCannon", configKey = "HandCannon", image = ui.images.ShopButton },

    -- Shotguns
    { label = "BushMaster", configKey = "BushMaster", image = ui.images.ShopButton },
}

local GAP      = 0.03   -- gap between grid cells (fraction of panel)

--- Creates the armory popup panel with a breakout detail view.
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

    -- Wire close button (closes entire armory)
    local closeBtn = armoryPanel:FindFirstChild("CloseBtn")
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(function()
            armoryPanel.Visible = false
        end)
    end

    -- ── Grid container ──────────────────────────────────────────────
    local scrollFrame = create "ScrollingFrame" {
        Name                   = "WeaponGrid",
        Parent                 = armoryPanel,
        Size                 = UDim2.new(0.96, 0, 0.85, 0),
        Position             = UDim2.new(0.02, 0, 0.15, 0),
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        CanvasSize           = UDim2.new(0, 0, 2, 0),
        ScrollBarThickness   = 6,
        ClipsDescendants     = true,
        ScrollBarImageColor3 = theme.ACCENT,

        create "UIGridLayout" {
            SortOrder      = Enum.SortOrder.LayoutOrder,
            CellSize       = UDim2.new(0.22, 0, 0.22, 0),
            CellPadding    = UDim2.new(GAP, 0, GAP, 0),
            FillDirection  = Enum.FillDirection.Horizontal,
        },

        create "Sound" {
            Name     = "ShopClick",
            SoundId  = ui.sounds.Click,
            Volume   = ui.button.clickVolume,
        },
    }

    -- ── Breakout detail panel (hidden by default) ───────────────────
    local breakoutPanel = create "Frame" {
        Name                   = "Breakout",
        Parent                 = armoryPanel,
        Size                   = UDim2.new(0.96, 0, 0.85, 0),
        Position               = UDim2.new(0.02, 0, 0.15, 0),
        BackgroundColor3       = theme.BACKGROUND_LIGHT,
        BorderSizePixel        = 0,
        Visible                = false,

        create "UICorner" {
            CornerRadius = theme.CORNER_RADIUS,
        },

        -- Back button (top-left)
        create "TextButton" {
            Name                   = "BackBtn",
            Size                   = UDim2.new(0.12, 0, 0.08, 0),
            Position               = UDim2.new(0.01, 0, 0.01, 0),
            BackgroundColor3       = Color3.fromRGB(90, 35, 35),
            TextColor3             = Color3.new(1, 1, 1),
            Text                   = "← Back",
            TextScaled             = true,
            Font                   = theme.FONT_BOLD,
            BorderSizePixel        = 0,
            AutoButtonColor        = true,

            create "UICorner" {
                CornerRadius = theme.BUTTON_CORNER,
            },
        },

        -- Card container (GunPurchaseCard is parented here)
        create "Frame" {
            Name                   = "CardContainer",
            Size                   = UDim2.new(0.85, 0, 0.88, 0),
            Position               = UDim2.new(0.14, 0, 0.09, 0),
            BackgroundTransparency = 1,
        },
    }

    -- State: currently selected weapon (cleared on back/close)
    local currentCard: Instance? = nil

    --- Show the breakout for a given weapon entry.
    local function showBreakout(entry: WeaponEntry)
        -- Remove previous card if any
        if currentCard then
            currentCard:Destroy()
            currentCard = nil
        end

        local cardContainer = breakoutPanel:FindFirstChild("CardContainer") :: Instance?
        if not cardContainer then return end

        -- If the weapon has a known config key, render a full GunPurchaseCard
        if entry.configKey then
            -- Dynamically require CombatConfig from ReplicatedStorage.Shared
            local shared = ReplicatedStorage:FindFirstChild("Shared")
            local combatCfg = nil
            if shared then
                local cfgModule = shared:FindFirstChild("CombatConfig")
                if cfgModule and cfgModule:IsA("ModuleScript") then
                    combatCfg = require(cfgModule)
                end
            end

            if combatCfg and combatCfg.GUN_STATS[entry.configKey] then
                currentCard = GunPurchaseCard({
                    parent   = cardContainer,
                    position = UDim2.new(0, 0, 0, 0),
                    size     = UDim2.new(1, 0, 1, 0),
                    gunName  = entry.configKey,
                    stats    = combatCfg.GUN_STATS[entry.configKey],
                    onBuy    = function()
                        -- TODO: fire purchase RemoteEvent for entry.configKey
                    end,
                })
            end
        end

        -- Hide grid, show breakout
        scrollFrame.Visible = false
        breakoutPanel.Visible = true
    end

    --- Hide breakout and return to grid view.
    local function hideBreakout()
        if currentCard then
            currentCard:Destroy()
            currentCard = nil
        end
        breakoutPanel.Visible = false
        scrollFrame.Visible = true
    end

    -- Wire back button
    local backBtn = breakoutPanel:FindFirstChild("BackBtn")
    if backBtn then
        backBtn.MouseButton1Click:Connect(hideBreakout)
    end

    -- ── Create grid buttons ────────────────────────────────────────
    for _, weapon in ipairs(weapons) do
        local entry = weapon  -- capture for closure
        DepressedButton({
            parent   = scrollFrame,
            position = UDim2.new(0.5, 0, 0.5, 0),
            image    = entry.image,
            size     = UDim2.new(1, 0, 1, 0),
            hoverSoundId = ui.sounds.HoverSoundId,
            onActivated = function()
                showBreakout(entry)
            end,
        })
    end

    return function()
        armoryPanel.Visible = not armoryPanel.Visible
        -- Reset to grid view when toggling off
        if not armoryPanel.Visible then
            hideBreakout()
        end
    end
end

return {
    createArmoryHUD = createArmoryHUD,
}
