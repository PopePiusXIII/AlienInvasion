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
local themeModule = require(script.Parent.VideTheme)
local theme = themeModule or { ACCENT = Color3.fromRGB(220, 60, 60) }

local create = vide.create

export type DepressedButtonProps = {
    parent: Instance,
    position: UDim2,
    image: string,
    size: UDim2,
    onActivated: () -> (),
    hoverSoundId: string?,
}

--- Creates a depressed ImageButton component.
--- Hover effect scales the image content via UIScale (works inside UIGridLayout too).
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

        create "UIScale" {
            Name  = "ImageScale",
            Scale = 1,
        },

        create "Sound" {
            Name     = "HoverSound",
            SoundId  = props.hoverSoundId or "rbxassetid://0",
            Volume   = 1.0,
        },

        MouseEnter = function()
            local btn = props.parent:FindFirstChild(uniqueName)
            if btn and btn:IsA("ImageButton") then
                local scale = btn:FindFirstChildWhichIsA("UIScale")
                if scale then
                    scale.Scale = 1.15
                end
                local hoverSound = btn:FindFirstChild("HoverSound")
                if hoverSound and hoverSound:IsA("Sound") and props.hoverSoundId then
                    hoverSound:Play()
                end
            end
        end,

        MouseLeave = function()
            local btn = props.parent:FindFirstChild(uniqueName)
            if btn and btn:IsA("ImageButton") then
                local scale = btn:FindFirstChildWhichIsA("UIScale")
                if scale then
                    scale.Scale = 1
                end
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
