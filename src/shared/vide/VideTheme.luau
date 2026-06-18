--!strict
--------------------------------------------------------------------------------
-- VideTheme.luau  (src/shared/vide)
-- Shared theming and style constants for all vide-based UI in AlienInvasion.
--
-- Usage:
--   local theme = require(ReplicatedStorage.Shared.VideTheme)
--   create "Frame" {
--       BackgroundColor3 = theme.BACKGROUND,
--       BorderSizePixel  = 0,
--   }
--------------------------------------------------------------------------------

local theme = {}

-- ── Colors ────────────────────────────────────────────────────────────────────

theme.BACKGROUND       = Color3.fromRGB(12, 12, 22)      -- Deep space dark
theme.BACKGROUND_LIGHT = Color3.fromRGB(25, 25, 45)      -- Slightly lighter panel bg
theme.ACCENT           = Color3.fromRGB(220, 60, 60)     -- Red accent (alien invasion theme)
theme.ACCENT_GREEN     = Color3.fromRGB(30, 155, 70)     -- Success / button green
theme.TEXT_PRIMARY     = Color3.new(1, 1, 1)             -- White text
theme.TEXT_SECONDARY   = Color3.fromRGB(195, 195, 195)   -- Muted gray text
theme.TEXT_HIGHLIGHT   = Color3.fromRGB(255, 80, 80)     -- Bright red for highlights
theme.SILVER           = Color3.fromRGB(230, 230, 230)   -- Silver currency color

-- ── Typography ────────────────────────────────────────────────────────────────

theme.FONT_BOLD    = Enum.Font.GothamBold
theme.FONT_REGULAR = Enum.Font.Gotham

-- ── Layout ────────────────────────────────────────────────────────────────────

theme.CORNER_RADIUS = UDim.new(0, 12)
theme.BUTTON_CORNER = UDim.new(0, 10)

return theme
