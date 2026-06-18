--!strict
--------------------------------------------------------------------------------
-- DepressedButton.luau  (src/shared/vide)
-- Reusable ImageButton with hover-shrink ("depressed") effect and click sound.
--
-- Follows the vide component pattern:
--   https://centau.github.io/vide/tut/crash-course/3-components.html
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.vide)
local ui   = require(script.Parent.UiConfig)

local create = vide.create

export type DepressedButtonProps = {
    parent: Instance,
    position: UDim2,
    image: string,
    size: UDim2,
    onActivated: () -> (),
}

--- Creates a depressed ImageButton component.
--- Hover effect is handled imperatively via MouseEnter/MouseLeave.
local function DepressedButton(props: DepressedButtonProps)
    local uniqueName = "DB_" .. tostring(math.random(100000, 999999))

    create "ImageButton" {
        Name                   = uniqueName,
        Parent                 = props.parent,
        Size                 = props.size,
        Position             = props.position,
        BackgroundTransparency = 1,
        Image                = props.image,
        AnchorPoint          = Vector2.new(0.5, 0.5),

        create "UIAspectRatioConstraint" {
            AspectRatio = 1,
        },

        MouseEnter = function()
            local btn = props.parent:FindFirstChild(uniqueName)
            if btn and btn:IsA("ImageButton") then
                btn.Size = ui.button.hoverSize
            end
        end,

        MouseLeave = function()
            local btn = props.parent:FindFirstChild(uniqueName)
            if btn and btn:IsA("ImageButton") then
                btn.Size = props.size
            end
        end,

        Activated = function()
            local sound = props.parent:FindFirstChild("ShopClick")
            if sound and sound:IsA("Sound") then
                sound:Play()
            end
            props.onActivated()
        end,
    }
end

return DepressedButton
