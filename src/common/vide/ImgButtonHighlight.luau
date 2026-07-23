local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)

local create = vide.create
local source = vide.source

export type ImgButtonHighlightedProps = {
    parent: Instance,
    position: UDim2,
    image: string,
    size: UDim2,
    onActivated: () -> (),
    hoverSoundId: string?,
}

local function CreateStroke(selected: vide.Source<boolean>)
	return create "UIStroke" {
		Name = "UIStroke",
		Color = function()
			return selected()
				and Color3.fromRGB(255, 0, 0)
				or Color3.fromRGB(0, 0, 0)
		end,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = 0.0531915,
	}
end

local function ImgButtonHighlighted(props: ImgButtonHighlightedProps)
	local hovered = source(false)

    local instance = create "ImageButton" {
        Name = "ImageButton",
        Parent = props.parent,
        BackgroundColor3 = Color3.new(1, 1, 1),
        Image = props.image,
        Position = props.position,
        Size = props.size,

		create "UICorner" {
			BottomLeftRadius = UDim.new(0.106383, 0),
			BottomRightRadius = UDim.new(0.106383, 0),
			TopLeftRadius = UDim.new(0.106383, 0),
			TopRightRadius = UDim.new(0.106383, 0),
		},

		create "UIAspectRatioConstraint" {
			AspectRatio = 1,
		},

        MouseEnter = function()
            hovered(true)

            local hoverSound = props.parent:FindFirstChild("HoverSound")
            if hoverSound and hoverSound:IsA("Sound") and props.hoverSoundId then
                hoverSound:Play()
            end
        end,

        MouseLeave = function()
            hovered(false)
        end,

        Activated = function()
            local sound = props.parent:FindFirstChild("ShopClick")
            if sound and sound:IsA("Sound") then
                sound:Play()
            end

            props.onActivated()
        end,


		CreateStroke(hovered),
	}

	return instance
end

return ImgButtonHighlighted