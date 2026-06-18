--!strict
--------------------------------------------------------------------------------
-- UiConfig.luau  (src/shared/vide)
-- Central registry for GUI assets: images, sounds, and button behavior.
-- Used by all vide components.
--
-- Usage:
--   local ui = require(ReplicatedStorage.Shared.vide.UiConfig)
--   create "ImageButton" {
--       Image = ui.images.ShopButton,
--   }
--
-- Replace the placeholder rbxassetid values with your actual asset IDs
-- from the Roblox Creator Hub / Inventory.
--------------------------------------------------------------------------------

local ui = {}

-- ── Images ────────────────────────────────────────────────────────────────────

ui.images = {
    MatchButton     = "rbxassetid://0",              -- Find Match / Cancel button icon
    ShopButton      = "rbxassetid://108175858281047", -- Shop button icon
    SilverIcon      = "rbxassetid://0",              -- Silver currency icon
    PlayerAvatar    = "rbxassetid://0",              -- Player avatar frame/icon
    PanelBackground = "rbxassetid://0",              -- Panel background texture/image
    AccentBar       = "rbxassetid://0",              -- Accent bar graphic
}

-- ── Sounds ────────────────────────────────────────────────────────────────────

ui.sounds = {
    Click   = "rbxassetid://139009780109934",  -- UI click/press sound
}

-- ── Button Behavior ───────────────────────────────────────────────────────────

ui.button = {
    normalSize     = UDim2.new(0, 50, 0, 50),
    hoverSize      = UDim2.new(0, 45, 0, 45),
    clickVolume    = 0.5,
}

return ui
