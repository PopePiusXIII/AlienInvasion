local SocialService = game:GetService("SocialService")
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
    ShopButton      = "rbxassetid://90029504881916", -- Shop button icon
    ClassShopButton = "rbxassetid://124983139179704", -- Shop button icon
    PlayButton      = "rbxassetid://133750960686182",
    SilverIcon      = "rbxassetid://0",              -- Silver currency icon
    PlayerAvatar    = "rbxassetid://0",              -- Player avatar frame/icon
    PanelBackground = "rbxassetid://0",              -- Panel background texture/image
    AccentBar       = "rbxassetid://0",             -- Accent bar graphic
    -- GUNS
    Scar            = "rbxassetid://85630207697247",
    Mp5             = "rbxassetid://120069135047702"
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
