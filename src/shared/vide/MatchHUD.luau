--!strict
--------------------------------------------------------------------------------
-- MatchHUD.luau  (src/shared/vide)
-- Reactive vide component for the in-game HUD during a match.
--
-- Renders:
--   - Wave announcement label (top-center, appears on wave start)
--   - Ammo counter (bottom-right)
--   - Silver currency display (bottom-left)
--
-- All state is reactive via vide signals — update a signal and the UI
-- re-renders automatically. No manual DOM manipulation needed.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide  = require(ReplicatedStorage.Packages.vide)
local theme = require(script.Parent.VideTheme)

local create = vide.create
local source = vide.source
local derive = vide.derive
local mount  = vide.mount

export type MatchHUDProps = {
    -- Optional: parent ScreenGui if you want to share with other UI.
    -- If nil, a new ScreenGui is created and parented to PlayerGui.
    parentGui: Instance?,
}

--- Creates the Match HUD.
--- Returns a control table for imperative updates from controllers,
--- and an unmount function for cleanup.
function createMatchHUD(props: MatchHUDProps): ({
    setWaveText:     (string) -> (),
    clearWaveText:   () -> (),
    setAmmoText:     (string, Color3) -> (),
    setSilverAmount: (number) -> (),
    setGoldAmount:   (number) -> (),
}, () -> ())
    local waveText     = source("")
    local ammoText     = source("")
    local ammoColor    = source(Color3.new(1, 1, 1))
    local silverAmount = source(0)
    local goldAmount   = source(0)

    -- Create or use existing ScreenGui
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

    -- Define the reactive component
    local function renderHUD()
        return {
            -- Wave announcement label (top-center, only visible when text is non-empty)
            derive(function()
                local text = waveText()
                if text == "" then return nil end
                return create "TextLabel" {
                    Name                   = "WaveLabel",
                    Size                 = UDim2.new(0.4, 0, 0.1, 0),
                    Position             = UDim2.new(0.3, 0, 0.1, 0),
                    BackgroundTransparency = 1,
                    TextColor3           = theme.TEXT_HIGHLIGHT,
                    TextScaled           = true,
                    Font                 = theme.FONT_BOLD,
                    Text                 = text,
                }
            end),

            -- Ammo counter (bottom-right)
            derive(function()
                local text  = ammoText()
                local color = ammoColor()
                if text == "" then return nil end
                return create "TextLabel" {
                    Name                   = "AmmoLabel",
                    Size                 = UDim2.new(0.18, 0, 0.07, 0),
                    Position             = UDim2.new(0.80, 0, 0.88, 0),
                    BackgroundTransparency = 1,
                    TextColor3           = color,
                    TextScaled           = true,
                    Font                 = theme.FONT_BOLD,
                    Text                 = text,
                }
            end),

            -- Silver currency display (bottom-left) — always visible
            derive(function()
                local amount = silverAmount()
                return create "TextLabel" {
                    Name                   = "SilverLabel",
                    Size                 = UDim2.new(0.24, 0, 0.06, 0),
                    Position             = UDim2.new(0.02, 0, 0.88, 0),
                    BackgroundTransparency = 1,
                    TextColor3           = theme.SILVER,
                    TextScaled           = true,
                    Font                 = theme.FONT_BOLD,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    Text                 = "SILVER: " .. tostring(math.max(0, math.floor(amount))),
                }
            end),

            -- Gold currency display (bottom-left, above silver) — always visible
            derive(function()
                local amount = goldAmount()
                return create "TextLabel" {
                    Name                   = "GoldLabel",
                    Size                 = UDim2.new(0.24, 0, 0.06, 0),
                    Position             = UDim2.new(0.02, 0, 0.81, 0),
                    BackgroundTransparency = 1,
                    TextColor3           = theme.GOLD,
                    TextScaled           = true,
                    Font                 = theme.FONT_BOLD,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    Text                 = "GOLD: " .. tostring(math.max(0, math.floor(amount))),
                }
            end),
        }
    end

    -- Mount the component into the ScreenGui
    local unmount = mount(renderHUD, screenGui)

    -- Control table for imperative updates from controllers
    local controls = {
        setWaveText = function(text: string) waveText(text) end,
        clearWaveText = function() waveText("") end,
        setAmmoText = function(text: string, color: Color3)
            ammoText(text)
            ammoColor(color)
        end,
        setSilverAmount = function(amount: number) silverAmount(amount) end,
        setGoldAmount   = function(amount: number) goldAmount(amount) end,
    }

    return controls, unmount
end

return {
    createMatchHUD = createMatchHUD,
}
