    local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide  = require(ReplicatedStorage.Packages.vide)
local theme = require(script.Parent.VideTheme)
local ui    = require(script.Parent.UiConfig)
local DepressedButton = require(script.Parent.DepressedButton)

local create = vide.create
function createArmoryHUD(screenGui: Instance): () -> ()

    local gunPanel = create "Frame" {
    Name                   = "GunPanel",
    Parent                 = screenGui,
    Size                 = UDim2.new(0.2, 0, 0.52, 0),
    Position             = UDim2.new(0.05, 0, 0.24, 0),
    BackgroundColor3     = theme.BACKGROUND,
    BackgroundTransparency = 0.1,
    BorderSizePixel      = 0,
    Visible              = false,

    create "UICorner" {
        CornerRadius = theme.CORNER_RADIUS,
    }
    }
    return function()
        gunPanel.Visible = not gunPanel.Visible
    end
end

return {
    createArmoryHUD = createArmoryHUD,
}
