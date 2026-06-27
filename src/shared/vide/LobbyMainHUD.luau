--!strict
--------------------------------------------------------------------------------
-- LobbyMainHUD.luau  (src/shared/vide)
-- The default HUD visible in the lobby at all times.
--
-- Shows:
--   - Game title (top-center)
--   - Player name + silver balance (top-left)
--   - Navigation hint text (bottom-center, e.g. "Walk to a pad to play")
--
-- Always-on, non-reactive panel — no show/hide toggling needed.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide  = require(ReplicatedStorage.Packages.vide)
local theme = require(script.Parent.VideTheme)
local ui    = require(script.Parent.UiConfig)
local DepressedButton = require(script.Parent.DepressedButton)
local armoryHud = require(script.Parent.Armory)

local create = vide.create
local source = vide.source
local derive = vide.derive
local root   = vide.root

export type LobbyMainHUDProps = {
    title: string,
    hintText: string,
}

--- Creates the always-visible lobby HUD.
--- Returns the ScreenGui instance and a control table for updating reactive fields.
function createLobbyMainHUD(props: LobbyMainHUDProps): (Instance, {
    setSilver: (number) -> (),
    setHint:   (string) -> (),
})
    local silverAmount = source(0)
    local hintMsg      = source(props.hintText)

    local screenGui = create "ScreenGui" {
        Name           = "LobbyMainHud",
        ResetOnSpawn   = false,
        IgnoreGuiInset = true,
    }

    -- Armory panel (created once, returns a toggle function)
    local toggleArmory = armoryHud.createArmoryHUD(screenGui)

    -- Click sound (static, not reactive)
    local clickSound = create "Sound" {
        Name     = "ShopClick",
        Parent   = screenGui,
        SoundId  = ui.sounds.Click,
        Volume   = ui.button.clickVolume,
    }

    -- Create a reactive scope; instances are parented manually via Parent property
    root(function()
        -- Game title (top-center) — static
        create "TextLabel" {
            Name                   = "Title",
            Parent                 = screenGui,
            Size                 = UDim2.new(0.5, 0, 0.1, 0),
            Position             = UDim2.new(0.25, 0, 0.02, 0),
            BackgroundTransparency = 1,
            TextColor3           = theme.TEXT_HIGHLIGHT,
            TextScaled           = true,
            Font                 = theme.FONT_BOLD,
            Text                 = props.title,
        }

        -- Player name (top-left) — static
        create "TextLabel" {
            Name                   = "PlayerName",
            Parent                 = screenGui,
            Size                 = UDim2.new(0.3, 0, 0.06, 0),
            Position             = UDim2.new(0.02, 0, 0.02, 0),
            BackgroundTransparency = 1,
            TextColor3           = theme.TEXT_PRIMARY,
            TextScaled           = true,
            Font                 = theme.FONT_BOLD,
            TextXAlignment       = Enum.TextXAlignment.Left,
            Text                 = Players.LocalPlayer.Name,
        }

        -- Silver balance (top-left, below player name) — reactive
        derive(function()
            return create "TextLabel" {
                Name                   = "SilverLabel",
                Parent                 = screenGui,
                Size                 = UDim2.new(0.3, 0, 0.06, 0),
                Position             = UDim2.new(0.02, 0, 0.09, 0),
                BackgroundTransparency = 1,
                TextColor3           = theme.SILVER,
                TextScaled           = true,
                Font                 = theme.FONT_REGULAR,
                TextXAlignment       = Enum.TextXAlignment.Left,
                Text                 = "SILVER: " .. tostring(math.max(0, math.floor(silverAmount()))),
            }
        end)

        -- Navigation hint (bottom-center) — reactive
        derive(function()
            return create "TextLabel" {
                Name                   = "Hint",
                Parent                 = screenGui,
                Size                 = UDim2.new(0.5, 0, 0.06, 0),
                Position             = UDim2.new(0.25, 0, 0.90, 0),
                BackgroundTransparency = 1,
                TextColor3           = theme.TEXT_SECONDARY,
                TextScaled           = true,
                Font                 = theme.FONT_REGULAR,
                Text                 = hintMsg(),
            }
        end)

        -- Shop button (bottom-center) — reusable DepressedButton component
        DepressedButton({
            parent   = screenGui,
            position = UDim2.new(0.93, 0, 0.3, 0),
            image    = ui.images.ClassShopButton,
            size     = ui.button.normalSize,
            onActivated = function()
                -- TODO: open shop UI
            end,
        })

        -- Shop button (bottom-center) — reusable DepressedButton component
        DepressedButton({
            parent   = screenGui,
            position = UDim2.new(0.93, 0, 0.5, 0),
            image    = ui.images.ShopButton,
            size     = ui.button.normalSize,
            onActivated = toggleArmory
        })

                -- Shop button (bottom-center) — reusable DepressedButton component
        DepressedButton({
            parent   = screenGui,
            position = UDim2.new(0.93, 0, 0.7, 0),
            image    = ui.images.PlayButton,
            size     = ui.button.normalSize,
            onActivated = function()
                -- TODO: open shop UI
            end,
        })


    end)

    local controls = {
        setSilver = function(amount: number) silverAmount(amount) end,
        setHint   = function(msg: string) hintMsg(msg) end,
    }

    return screenGui, controls
end

return {
    createLobbyMainHUD = createLobbyMainHUD,
}
