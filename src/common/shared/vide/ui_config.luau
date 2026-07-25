--!strict
--------------------------------------------------------------------------------
-- UiConfig.luau  (src/common/vide)
-- Central registry for GUI assets: images, sounds, and button behavior.
-- Used by all vide components.
--
-- Usage:
--   local ui = require(replicated_storage.shared.vide.UiConfig)
--   create "ImageButton" {
--       Image = ui.images.ShopButton,
--   }
--
-- Replace the placeholder rbxassetid values with your actual asset IDs
-- from the Roblox Creator Hub / Inventory.
--------------------------------------------------------------------------------

local ui = {}

-- ── Images ────────────────────────────────────────────────────────────────────
local placeholder = "rbxassetid://90029504881916"

ui.images = {
    MatchButton     = placeholder,              -- Find Match / Cancel button icon
    ShopButton      = "rbxassetid://90029504881916", -- Shop button icon
    ClassShopButton = "rbxassetid://124983139179704", -- Shop button icon
    PlayButton      = "rbxassetid://133750960686182",
    SilverIcon      = placeholder,              -- Silver currency icon
    PlayerAvatar    = placeholder,              -- Player avatar frame/icon
    PanelBackground = placeholder,              -- Panel background texture/image
    AccentBar       = placeholder,             -- Accent bar graphic
    BuyButton       = "rbxassetid://83427476792515",
    -- GUNS
    Scar            = "rbxassetid://85630207697247",
    Mp5             = "rbxassetid://120069135047702",
    M82             = "rbxassetid://100661199344163"
}

-- ── Sounds ────────────────────────────────────────────────────────────────────

ui.sounds = {
    Click   = "rbxassetid://139009780109934",  -- UI click/press sound
    HoverSoundId    = "rbxassetid://136108770017536",

}

-- ── Button Behavior ───────────────────────────────────────────────────────────

ui.button = {
    normalSize     = UDim2.new(0, 75, 0, 75),
    hoverSize      = UDim2.new(0, 70, 0, 70),
    clickVolume    = 0.5,
}

return ui
