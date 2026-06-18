--!strict
--------------------------------------------------------------------------------
-- MatchmakingHUD.luau  (src/shared/vide)
-- Reactive vide component for the matchmaking UI.
-- Only rendered when the player enters the matchmaking area.
--
-- Renders a centered panel with:
--   - Title label ("ALIEN INVASION")
--   - Status text (queue state messages)
--   - Action button (Find Match / Cancel / etc.)
--   - Shop button
--
-- All state is reactive via vide signals — update the signal and the UI
-- re-renders automatically.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide  = require(ReplicatedStorage.Packages.vide)
local theme = require(script.Parent.VideTheme)

local create = vide.create
local source = vide.source
local derive = vide.derive
local switch = vide.switch
local root   = vide.root

export type MatchmakingHUDProps = {
    title: string,
    statusText: string,
    buttonText: string,
    onButtonClicked: () -> (),
    onShopClicked: () -> (),
}

--- Creates the Matchmaking ScreenGui.
--- Returns the ScreenGui instance and a control table for imperative updates.
function createMatchmakingHUD(props: MatchmakingHUDProps): (Instance, {
    setVisible: (boolean) -> (),
    setStatus:  (string) -> (),
    setButton:  (string, boolean) -> (),
})
    local panelVisible = source(false)
    local statusMsg    = source(props.statusText)
    local btnText      = source(props.buttonText)
    local btnEnabled   = source(true)

    local screenGui = create "ScreenGui" {
        Name           = "LobbyMatchmakingGui",
        ResetOnSpawn   = false,
        IgnoreGuiInset = true,
    }

    -- Create reactive scope; instances are parented via Parent property
    root(function()
        switch(panelVisible, {
            [false] = nil,
            [true] = create "Frame" {
                Name                 = "Panel",
                Parent               = screenGui,
                Size               = UDim2.new(0.34, 0, 0.28, 0),
                Position           = UDim2.new(0.33, 0, 0.36, 0),
                BackgroundColor3   = theme.BACKGROUND,
                BackgroundTransparency = 0.15,
                BorderSizePixel    = 0,

                create "UICorner" {
                    CornerRadius = theme.CORNER_RADIUS,
                },

                -- Red accent bar at top
                create "Frame" {
                    Name              = "Accent",
                    Size             = UDim2.new(1, 0, 0.07, 0),
                    BackgroundColor3 = theme.ACCENT,
                    BorderSizePixel  = 0,
                    create "UICorner" {
                        CornerRadius = theme.CORNER_RADIUS,
                    },
                },

                -- Title label
                create "TextLabel" {
                    Name                   = "Title",
                    Size                 = UDim2.new(1, 0, 0.28, 0),
                    Position             = UDim2.new(0, 0, 0.08, 0),
                    BackgroundTransparency = 1,
                    TextColor3           = theme.TEXT_PRIMARY,
                    TextScaled           = true,
                    Font                 = theme.FONT_BOLD,
                    Text                 = props.title,
                },

                -- Reactive status text
                derive(function()
                    return create "TextLabel" {
                        Name                   = "Status",
                        Size                 = UDim2.new(0.88, 0, 0.2, 0),
                        Position             = UDim2.new(0.06, 0, 0.38, 0),
                        BackgroundTransparency = 1,
                        TextColor3           = theme.TEXT_SECONDARY,
                        TextScaled           = true,
                        Font                 = theme.FONT_REGULAR,
                        Text                 = statusMsg(),
                    }
                end),

                -- Reactive action button
                derive(function()
                    return create "TextButton" {
                        Name                = "MatchButton",
                        Size              = UDim2.new(0.58, 0, 0.24, 0),
                        Position          = UDim2.new(0.21, 0, 0.66, 0),
                        BackgroundColor3 = theme.ACCENT_GREEN,
                        BorderSizePixel   = 0,
                        TextColor3       = theme.TEXT_PRIMARY,
                        TextScaled       = true,
                        Font             = theme.FONT_BOLD,
                        Text             = btnText(),
                        AutoButtonColor  = btnEnabled(),

                        create "UICorner" {
                            CornerRadius = theme.BUTTON_CORNER,
                        },

                        Activated = function()
                            if btnEnabled() then
                                props.onButtonClicked()
                            end
                        end,
                    }
                end),
            },
        })
    end)

    -- Control table for imperative updates from controllers
    local controls = {
        setVisible = function(visible: boolean) panelVisible(visible) end,
        setStatus  = function(msg: string) statusMsg(msg) end,
        setButton  = function(text: string, enabled: boolean)
            btnText(text)
            btnEnabled(enabled)
        end,
    }

    return screenGui, controls
end

return {
    createMatchmakingHUD = createMatchmakingHUD,
}
