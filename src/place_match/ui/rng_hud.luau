local replicated_storage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local vide  = require(replicated_storage.Packages.vide)
local ImgButtonHighlight = require(replicated_storage.common.shared.vide.img_button_highlight)
local MatchHUD = require(replicated_storage.match.ui.match_hud)
local ModifierConfig = require(replicated_storage.match.shared.configs.match_profile_config)

local create = vide.create
local source = vide.source
local root   = vide.root
local cleanup = vide.cleanup

local ACTION_NAME = "RngHud_Select"
local optionLabels = source({ "", "", "" })
local selectionHandler: ((string) -> ())? = nil
local optionImageButtons: { ImageButton } = {}

local rngHudFrame = create "Frame" {
    Name = "Frame",
    Parent = MatchHUD.gui,
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderColor3 = Color3.new(),
    BorderSizePixel = 0,
    Position = UDim2.fromScale(0.505834, 0.274347),
    Size = UDim2.fromScale(0.483333, 0.24537),
	Visible = false,

    create "ImageLabel" {
        Name = "Black_Stud_Background",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        Image = "rbxassetid://6927295847",
        Position = UDim2.fromScale(0.5, 0.498113),
        ScaleType = Enum.ScaleType.Tile,
        Size = UDim2.fromScale(1, 1),
        TileSize = UDim2.fromOffset(100, 100),

        create "UICorner" {
            Name = "UICorner",
            BottomLeftRadius = UDim.new(0.0754717, 0),
            BottomRightRadius = UDim.new(0.0754717, 0),
            TopLeftRadius = UDim.new(0.0754717, 0),
            TopRightRadius = UDim.new(0.0754717, 0),
        },

        create "UIStroke" {
            Name = "UIStroke",
            StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
            Thickness = 0.0377358,
        },

        create "UIAspectRatioConstraint" {
            Name = "UIAspectRatioConstraint",
            AspectRatio = 3.50189,
        },
    },

    create "ImageLabel" {
        Name = "Black_Stud_Background",
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        Image = "rbxassetid://6927295847",
        Position = UDim2.fromScale(0, -0.173585),
        ScaleType = Enum.ScaleType.Tile,
        Size = UDim2.fromScale(1, 0.171205),
        TileSize = UDim2.fromOffset(100, 100),

        create "UICorner" {
            Name = "UICorner",
            BottomLeftRadius = UDim.new(0.440825, 0),
            BottomRightRadius = UDim.new(0.440825, 0),
            TopLeftRadius = UDim.new(0.440825, 0),
            TopRightRadius = UDim.new(0.440825, 0),
        },

        create "UIStroke" {
            Name = "UIStroke",
            StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
            Thickness = 0.220413,
        },

        create "TextLabel" {
            Name = "TextLabel",
            BackgroundTransparency = 1,
            FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
            Position = UDim2.fromScale(0.298491, -0.484908),
            RichText = true,
            Size = UDim2.fromScale(0.377472, 2.97687),
            Text = "Select Your Skill",
            TextColor3 = Color3.fromRGB(255, 0, 0),
            TextScaled = true,
            TextStrokeColor3 = Color3.fromRGB(255, 0, 0),

            create "UIPadding" {
                Name = "UIPadding",
                PaddingBottom = UDim.new(-0.0866667, 0),
                PaddingTop = UDim.new(-0.0866667, 0),
            },

            create "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
                AspectRatio = 4,
            },
        },

        create "UIAspectRatioConstraint" {
            Name = "UIAspectRatioConstraint",
            AspectRatio = 20.4543,
        },
    },

    create "UIAspectRatioConstraint" {
        Name = "UIAspectRatioConstraint",
        AspectRatio = 3.50189,
    },
}

local destroyRoot = root(function()
    local selectedIndex = source(1)
    local buttons = {}
    local fHeld = false
    local holdToken = 0
    local holdActivated = false

    for _, button in {
        {
            image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
            position = UDim2.fromScale(0.742457, 0.141089),
        },
        {
            image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
            position = UDim2.fromScale(0.0538793, 0.144862),
        },
        {
            image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
            position = UDim2.fromScale(0.398707, 0.141089),
        },
    } do
        local index = #buttons + 1
        local onActivated = function()
            local option = optionLabels()[index]
            if option and selectionHandler then
                selectionHandler(option)
            end
        end

        local imageButton = ImgButtonHighlight({
            parent = rngHudFrame,
            image = button.image,
            position = button.position,
            size = UDim2.fromScale(0.202586, 0.709434),
            onActivated = onActivated,
            isSelected = function()
                return selectedIndex() == index
            end,
        })

        table.insert(optionImageButtons, imageButton)

        table.insert(buttons, onActivated)
    end

    local function handleF(_, inputState)
        if not rngHudFrame.Visible then
            return Enum.ContextActionResult.Pass
        end

        if inputState == Enum.UserInputState.Begin then
            if fHeld then
                return Enum.ContextActionResult.Sink
            end

            fHeld = true
            holdActivated = false
            holdToken += 1
            local token = holdToken

            task.delay(0.5, function()
                if fHeld and holdToken == token then
                    holdActivated = true
                    buttons[selectedIndex()]()
                end
            end)
        elseif inputState == Enum.UserInputState.End then
            if not fHeld then
                return Enum.ContextActionResult.Sink
            end

            fHeld = false
            holdToken += 1

            if not holdActivated then
                selectedIndex(selectedIndex() % #buttons + 1)
            end
        end

        return Enum.ContextActionResult.Sink
    end

    ContextActionService:UnbindAction(ACTION_NAME)
    ContextActionService:BindActionAtPriority(
        ACTION_NAME,
        handleF,
        false,
        Enum.ContextActionPriority.High.Value,
        Enum.KeyCode.F
    )

    cleanup(function()
        ContextActionService:UnbindAction(ACTION_NAME)
    end)
end)

MatchHUD.gui.Destroying:Once(destroyRoot)

local RngHud = {}

function RngHud.show(options: { string }, onSelected: (string) -> ())
    optionLabels(options)
    for index, key in ipairs(options) do
        optionImageButtons[index].Image = ModifierConfig[key].image
    end
    selectionHandler = function(option: string)
        selectionHandler = nil
        rngHudFrame.Visible = false
        onSelected(option)
    end
    rngHudFrame.Visible = true
end

return RngHud
