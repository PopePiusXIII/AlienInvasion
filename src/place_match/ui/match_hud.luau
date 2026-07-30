local replicated_storage = game:GetService("ReplicatedStorage")
local vide  = require(replicated_storage.Packages.vide)

local create = vide.create
local source = vide.source
local effect = vide.effect
local mount  = vide.mount
local root   = vide.root
local cleanup = vide.cleanup

create "ScreenGui" {
    Name = "MatchHud",
    ResetOnSpawn = false,
    ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

    create "Frame" {
        Name = "Container",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),

        create "Frame" {
            Name = "Skill_Frame",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.0756136, 0.499794),
            Size = UDim2.fromScale(0.142445, 0.251786),

            create "Folder" {
                Name = "Skill_1",

                create "ImageLabel" {
                    Name = "Purple_Background_Image",
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Image = "rbxassetid://106909274584862",
                    Position = UDim2.fromScale(0.0382203, 0.046932),
                    Size = UDim2.fromScale(0.92328, 0.141846),

                    create "UIStroke" {
                        Name = "UIStroke",
                        Color = Color3.fromRGB(113, 46, 206),
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.05,
                    },

                    create "UICorner" {
                        Name = "UICorner",
                        BottomLeftRadius = UDim.new(0, 4),
                        BottomRightRadius = UDim.new(0, 4),
                        TopLeftRadius = UDim.new(0, 4),
                        TopRightRadius = UDim.new(0, 4),
                    },
                },

                create "ImageLabel" {
                    Name = "Skill_1_Icon",
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(),
                    BorderSizePixel = 0,
                    Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
                    Position = UDim2.fromScale(0.102708, 0.0575705),
                    Size = UDim2.fromScale(0.121697, 0.108505),
                },

                create "TextLabel" {
                    Name = "Skill_1_Text_Label",
                    BackgroundTransparency = 1,
                    FontFace = Font.new(
                        "rbxasset://fonts/families/RobotoMono.json",
                        Enum.FontWeight.Bold,
                        Enum.FontStyle.Italic
                    ),
                    Position = UDim2.fromScale(0.273602, 0.0451318),
                    Size = UDim2.fromScale(0.651961, 0.1401),
                    Text = "Skill 1",
                    TextColor3 = Color3.fromRGB(107, 100, 237),
                    TextScaled = true,
                    ZIndex = 2,

                    create "UIStroke" {
                        Name = "UIStroke",
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.002,
                    },
                },
            },

            create "Folder" {
                Name = "Skill_2",

                create "ImageLabel" {
                    Name = "Purple_Background_Image",
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Image = "rbxassetid://106909274584862",
                    Position = UDim2.fromScale(0.0382203, 0.217145),
                    Size = UDim2.fromScale(0.92328, 0.141846),

                    create "UIStroke" {
                        Name = "UIStroke",
                        Color = Color3.fromRGB(113, 46, 206),
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.05,
                    },

                    create "UICorner" {
                        Name = "UICorner",
                        BottomLeftRadius = UDim.new(0, 4),
                        BottomRightRadius = UDim.new(0, 4),
                        TopLeftRadius = UDim.new(0, 4),
                        TopRightRadius = UDim.new(0, 4),
                    },
                },

                create "ImageLabel" {
                    Name = "Skill_2_Icon",
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(),
                    BorderSizePixel = 0,
                    Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
                    Position = UDim2.fromScale(0.100983, 0.229569),
                    Size = UDim2.fromScale(0.123423, 0.106447),
                },

                create "TextLabel" {
                    Name = "Skill_2_Text_Label",
                    BackgroundTransparency = 1,
                    FontFace = Font.new(
                        "rbxasset://fonts/families/RobotoMono.json",
                        Enum.FontWeight.Bold,
                        Enum.FontStyle.Italic
                    ),
                    Position = UDim2.fromScale(0.269553, 0.215345),
                    Size = UDim2.fromScale(0.651961, 0.1401),
                    Text = "Skill 2",
                    TextColor3 = Color3.fromRGB(107, 100, 237),
                    TextScaled = true,
                    ZIndex = 2,

                    create "UIStroke" {
                        Name = "UIStroke",
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.002,
                    },
                },
            },

            create "Folder" {
                Name = "Skill_3",

                create "ImageLabel" {
                    Name = "Purple_Background_Image",
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Image = "rbxassetid://106909274584862",
                    Position = UDim2.fromScale(0.0382203, 0.387357),
                    Size = UDim2.fromScale(0.92328, 0.141846),

                    create "UIStroke" {
                        Name = "UIStroke",
                        Color = Color3.fromRGB(113, 46, 206),
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.05,
                    },

                    create "UICorner" {
                        Name = "UICorner",
                        BottomLeftRadius = UDim.new(0, 4),
                        BottomRightRadius = UDim.new(0, 4),
                        TopLeftRadius = UDim.new(0, 4),
                        TopRightRadius = UDim.new(0, 4),
                    },
                },

                create "ImageLabel" {
                    Name = "Skill_3_Icon",
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(),
                    BorderSizePixel = 0,
                    Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
                    Position = UDim2.fromScale(0.100983, 0.406874),
                    Size = UDim2.fromScale(0.123423, 0.106502),
                },

                create "TextLabel" {
                    Name = "Skill_3_Text_Label",
                    BackgroundTransparency = 1,
                    FontFace = Font.new(
                        "rbxasset://fonts/families/RobotoMono.json",
                        Enum.FontWeight.Bold,
                        Enum.FontStyle.Italic
                    ),
                    Position = UDim2.fromScale(0.269553, 0.389103),
                    Size = UDim2.fromScale(0.651961, 0.1401),
                    Text = "Skill 3",
                    TextColor3 = Color3.fromRGB(107, 100, 237),
                    TextScaled = true,
                    ZIndex = 2,

                    create "UIStroke" {
                        Name = "UIStroke",
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.002,
                    },
                },
            },

            create "Folder" {
                Name = "Skill_4",

                create "ImageLabel" {
                    Name = "Purple_Background_Image",
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Image = "rbxassetid://106909274584862",
                    Position = UDim2.fromScale(0.0382203, 0.55757),
                    Size = UDim2.fromScale(0.92328, 0.141846),

                    create "UIStroke" {
                        Name = "UIStroke",
                        Color = Color3.fromRGB(113, 46, 206),
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.05,
                    },

                    create "UICorner" {
                        Name = "UICorner",
                        BottomLeftRadius = UDim.new(0, 4),
                        BottomRightRadius = UDim.new(0, 4),
                        TopLeftRadius = UDim.new(0, 4),
                        TopRightRadius = UDim.new(0, 4),
                    },
                },

                create "ImageLabel" {
                    Name = "Skill_4_Icon",
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(),
                    BorderSizePixel = 0,
                    Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
                    Position = UDim2.fromScale(0.100983, 0.573541),
                    Size = UDim2.fromScale(0.123423, 0.106502),
                },

                create "TextLabel" {
                    Name = "Skill_4_Text_Label",
                    BackgroundTransparency = 1,
                    FontFace = Font.new(
                        "rbxasset://fonts/families/RobotoMono.json",
                        Enum.FontWeight.Bold,
                        Enum.FontStyle.Italic
                    ),
                    Position = UDim2.fromScale(0.269553, 0.559316),
                    Size = UDim2.fromScale(0.651961, 0.1401),
                    Text = "Skill 4",
                    TextColor3 = Color3.fromRGB(107, 100, 237),
                    TextScaled = true,
                    ZIndex = 2,

                    create "UIStroke" {
                        Name = "UIStroke",
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.002,
                    },
                },
            },

            create "Folder" {
                Name = "Skill_5",

                create "ImageLabel" {
                    Name = "Purple_Background_Image",
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Image = "rbxassetid://106909274584862",
                    Position = UDim2.fromScale(0.0382203, 0.731329),
                    Size = UDim2.fromScale(0.92328, 0.141846),

                    create "UIStroke" {
                        Name = "UIStroke",
                        Color = Color3.fromRGB(113, 46, 206),
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.05,
                    },

                    create "UICorner" {
                        Name = "UICorner",
                        BottomLeftRadius = UDim.new(0, 4),
                        BottomRightRadius = UDim.new(0, 4),
                        TopLeftRadius = UDim.new(0, 4),
                        TopRightRadius = UDim.new(0, 4),
                    },
                },

                create "ImageLabel" {
                    Name = "Skill_5_Icon",
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(),
                    BorderSizePixel = 0,
                    Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
                    Position = UDim2.fromScale(0.0969343, 0.743753),
                    Size = UDim2.fromScale(0.124459, 0.106906),
                },

                create "TextLabel" {
                    Name = "Skill_5_Text_Label",
                    BackgroundTransparency = 1,
                    FontFace = Font.new(
                        "rbxasset://fonts/families/RobotoMono.json",
                        Enum.FontWeight.Bold,
                        Enum.FontStyle.Italic
                    ),
                    Position = UDim2.fromScale(0.269553, 0.729529),
                    Size = UDim2.fromScale(0.651961, 0.1401),
                    Text = "Skill 5",
                    TextColor3 = Color3.fromRGB(107, 100, 237),
                    TextScaled = true,
                    ZIndex = 2,

                    create "UIStroke" {
                        Name = "UIStroke",
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.002,
                    },
                },
            },
        },

        create "Frame" {
            Name = "Health_Frame",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.117647, 0.928571),
            Size = UDim2.fromScale(0.198385, 0.0892857),

            create "ImageLabel" {
                Name = "Purple_Background",
                BackgroundColor3 = Color3.new(1, 1, 1),
                Image = "rbxassetid://106909274584862",
                Position = UDim2.fromScale(-0.0472093, 0.29),
                Size = UDim2.fromScale(0.997093, 0.76),

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.fromRGB(113, 46, 206),
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.01,
                },

                create "TextLabel" {
                    Name = "HP",
                    BackgroundTransparency = 1,
                    FontFace = Font.new(
                        "rbxasset://fonts/families/RobotoMono.json",
                        Enum.FontWeight.Regular,
                        Enum.FontStyle.Italic
                    ),
                    Position = UDim2.fromScale(0.0612026, 0.0954654),
                    Size = UDim2.fromScale(0.103316, 0.354737),
                    Text = "HP",
                    TextColor3 = Color3.fromRGB(107, 100, 237),
                    TextScaled = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,

                    create "UIStroke" {
                        Name = "UIStroke",
                        Color = Color3.fromRGB(107, 100, 237),
                        LineJoinMode = Enum.LineJoinMode.Miter,
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.03125,
                    },
                },

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0, 4),
                    BottomRightRadius = UDim.new(0, 4),
                    TopLeftRadius = UDim.new(0, 4),
                    TopRightRadius = UDim.new(0, 4),
                },
            },

            create "Frame" {
                Name = "Grey_Background_Frame",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(35, 35, 35),
                BorderColor3 = Color3.new(),
                BorderSizePixel = 0,
                Position = UDim2.fromScale(0.453488, 0.795),
                Size = UDim2.fromScale(0.912791, 0.29),

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.0344828,
                },
            },

            create "Frame" {
                Name = "Purple_HealthBar",
                BackgroundColor3 = Color3.fromRGB(107, 100, 237),
                BorderColor3 = Color3.new(),
                BorderSizePixel = 0,
                Position = UDim2.fromScale(-0.00290698, 0.65),
                Size = UDim2.fromScale(0.912791, 0.29),
            },

            create "TextLabel" {
                Name = "76 / 100",
                BackgroundTransparency = 1,
                FontFace = Font.new(
                    "rbxasset://fonts/families/RobotoMono.json",
                    Enum.FontWeight.Regular,
                    Enum.FontStyle.Italic
                ),
                LayoutOrder = 1,
                Position = UDim2.fromScale(0.336492, 0.68973),
                Size = UDim2.fromScale(0.235474, 0.21),
                Text = "76 / 100",
                TextColor3 = Color3.new(),
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 2,

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.fromRGB(107, 100, 237),
                    LineJoinMode = Enum.LineJoinMode.Miter,
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.03125,
                },
            },
        },

        create "Frame" {
            Name = "XP_Frame",
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 0, 0, 10),
            Size = UDim2.fromOffset(1877, 46),

            create "ImageLabel" {
                Name = "Purple_Background",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Image = "rbxassetid://106909274584862",
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(1, 1),

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.fromRGB(113, 46, 206),
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.01,
                },

                create "TextLabel" {
                    Name = "XP_Text_Label",
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    FontFace = Font.new(
                        "rbxasset://fonts/families/RobotoMono.json",
                        Enum.FontWeight.Bold,
                        Enum.FontStyle.Italic
                    ),
                    Position = UDim2.new(0, 15, 0.463684, 0),
                    Size = UDim2.fromScale(0.0158279, 0.627368),
                    Text = "XP",
                    TextColor3 = Color3.fromRGB(107, 100, 237),
                    TextScaled = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,

                    create "UIStroke" {
                        Name = "UIStroke",
                        Color = Color3.fromRGB(107, 100, 237),
                        LineJoinMode = Enum.LineJoinMode.Miter,
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.03125,
                    },
                },

                create "UICorner" {
                    Name = "UICorner",
                },
            },

            create "Frame" {
                Name = "Grey_Background_Frame",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(35, 35, 35),
                BorderColor3 = Color3.new(),
                BorderSizePixel = 0,
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(0.9, 0.9),

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.0344828,
                },
            },

            create "Frame" {
                Name = "Purple_HealthBar",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(107, 100, 237),
                BorderColor3 = Color3.new(),
                BorderSizePixel = 0,
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(0.9, 0.85),

                create "UIGradient" {
                    Name = "UIGradient",
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(64, 60, 141)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(112, 107, 255)),
                    }),
                },
            },

            create "TextLabel" {
                Name = "TextLabel",
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json"),
                Position = UDim2.new(0.5, 0, 0, -10),
                Size = UDim2.fromScale(0.334302, 0.24),
                Text = "100/1000",
                TextColor3 = Color3.fromRGB(107, 100, 237),
                TextScaled = true,

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.00625,
                },
            },

            create "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
                AspectRatio = 53.85,
                AspectType = Enum.AspectType.ScaleWithParentSize,
            },
        },

        create "Frame" {
            Name = "Weapons",
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.5, 0.898148),
            Size = UDim2.fromOffset(338, 110),

            create "CanvasGroup" {
                Name = "CanvasGroup",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.fromOffset(100, 100),

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0.1, 0),
                    BottomRightRadius = UDim.new(0.1, 0),
                    TopLeftRadius = UDim.new(0.1, 0),
                    TopRightRadius = UDim.new(0.1, 0),
                },

                create "TextLabel" {
                    Name = "TextLabel",
                    AnchorPoint = Vector2.new(0.5, 0),
                    BackgroundTransparency = 1,
                    FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json"),
                    Position = UDim2.fromScale(0.5, 0.538128),
                    Size = UDim2.fromOffset(200, 50),
                    Text = "10/30",
                    TextColor3 = Color3.new(),
                    TextSize = 14,
                    ZIndex = 2,
                },

                create "ImageButton" {
                    Name = "ImageButton",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(),
                    BorderSizePixel = 0,
                    Image = "rbxassetid://83770969993177",
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 1),
                },
            },

            create "CanvasGroup" {
                Name = "CanvasGroup",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(100, 100),

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0.1, 0),
                    BottomRightRadius = UDim.new(0.1, 0),
                    TopLeftRadius = UDim.new(0.1, 0),
                    TopRightRadius = UDim.new(0.1, 0),
                },

                create "TextLabel" {
                    Name = "TextLabel",
                    AnchorPoint = Vector2.new(0.5, 0),
                    BackgroundTransparency = 1,
                    FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json"),
                    Position = UDim2.fromScale(0.5, 0.538128),
                    Size = UDim2.fromOffset(200, 50),
                    Text = "10/30",
                    TextColor3 = Color3.new(),
                    TextSize = 14,
                    ZIndex = 2,
                },

                create "ImageButton" {
                    Name = "ImageButton",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(),
                    BorderSizePixel = 0,
                    Image = "rbxassetid://83770969993177",
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 1),
                },
            },

            create "CanvasGroup" {
                Name = "CanvasGroup",
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Position = UDim2.fromScale(1, 0.5),
                Size = UDim2.fromOffset(100, 100),

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0.1, 0),
                    BottomRightRadius = UDim.new(0.1, 0),
                    TopLeftRadius = UDim.new(0.1, 0),
                    TopRightRadius = UDim.new(0.1, 0),
                },

                create "TextLabel" {
                    Name = "TextLabel",
                    AnchorPoint = Vector2.new(0.5, 0),
                    BackgroundTransparency = 1,
                    FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json"),
                    Position = UDim2.fromScale(0.5, 0.538128),
                    Size = UDim2.fromOffset(200, 50),
                    Text = "10/30",
                    TextColor3 = Color3.new(),
                    TextSize = 14,
                    ZIndex = 2,
                },

                create "ImageButton" {
                    Name = "ImageButton",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderColor3 = Color3.new(),
                    BorderSizePixel = 0,
                    Image = "rbxassetid://83770969993177",
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 1),
                },
            },
        },

        create "Frame" {
            Name = "Kills",
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.0108309, 0.0549432),
            Size = UDim2.fromScale(0.130317, 0.0825394),

            create "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
                AspectRatio = 4.34,
            },

            create "ImageLabel" {
                Name = "ImageLabel",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://121467172736704",
                Position = UDim2.fromScale(0.554454, 0.5),
                Size = UDim2.fromScale(0.0592586, 0.257182),
                ZIndex = 2,
            },

            create "TextLabel" {
                Name = "23",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                FontFace = Font.new(
                    "rbxasset://fonts/families/RobotoMono.json",
                    Enum.FontWeight.Bold,
                    Enum.FontStyle.Italic
                ),
                Position = UDim2.fromScale(0.810323, 0.5),
                Size = UDim2.fromScale(0.163036, 0.301018),
                Text = "1000",
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 2,

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.new(1, 1, 1),
                    LineJoinMode = Enum.LineJoinMode.Miter,
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.015625,
                },
            },

            create "TextLabel" {
                Name = "KILLS",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                FontFace = Font.new(
                    "rbxasset://fonts/families/RobotoMono.json",
                    Enum.FontWeight.Regular,
                    Enum.FontStyle.Italic
                ),
                LayoutOrder = 1,
                Position = UDim2.fromScale(0.631603, 0.5),
                Size = UDim2.fromScale(0.160287, 0.288537),
                Text = "Coins",
                TextColor3 = Color3.fromRGB(107, 100, 237),
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 2,

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.fromRGB(107, 100, 237),
                    LineJoinMode = Enum.LineJoinMode.Miter,
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.015625,
                },
            },

            create "TextLabel" {
                Name = "KILLS",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                FontFace = Font.new(
                    "rbxasset://fonts/families/RobotoMono.json",
                    Enum.FontWeight.Bold,
                    Enum.FontStyle.Normal
                ),
                LayoutOrder = 1,
                Position = UDim2.fromScale(0.431142, 0.5),
                Size = UDim2.fromScale(0.0804145, 0.863177),
                Text = "|",
                TextColor3 = Color3.fromRGB(107, 100, 237),
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 2,

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.fromRGB(107, 100, 237),
                    LineJoinMode = Enum.LineJoinMode.Miter,
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.015625,
                },
            },

            create "TextLabel" {
                Name = "23",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                FontFace = Font.new(
                    "rbxasset://fonts/families/RobotoMono.json",
                    Enum.FontWeight.Bold,
                    Enum.FontStyle.Italic
                ),
                Position = UDim2.fromScale(0.282673, 0.5),
                Size = UDim2.fromScale(0.163036, 0.301018),
                Text = "1000",
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 2,

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.new(1, 1, 1),
                    LineJoinMode = Enum.LineJoinMode.Miter,
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.015625,
                },
            },

            create "ImageLabel" {
                Name = "ImageLabel",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://121467172736704",
                Position = UDim2.fromScale(0.0221961, 0.5),
                Size = UDim2.fromScale(0.0592586, 0.257182),
                ZIndex = 2,
            },

            create "TextLabel" {
                Name = "KILLS",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                FontFace = Font.new(
                    "rbxasset://fonts/families/RobotoMono.json",
                    Enum.FontWeight.Regular,
                    Enum.FontStyle.Italic
                ),
                LayoutOrder = 1,
                Position = UDim2.fromScale(0.0970407, 0.5),
                Size = UDim2.fromScale(0.160287, 0.288537),
                Text = "KILLS",
                TextColor3 = Color3.fromRGB(107, 100, 237),
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 2,

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.fromRGB(107, 100, 237),
                    LineJoinMode = Enum.LineJoinMode.Miter,
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.015625,
                },
            },

            create "ImageLabel" {
                Name = "Purple_Background_Image",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Image = "rbxassetid://106909274584862",
                Position = UDim2.fromScale(-0.00560117, 0.5),
                Size = UDim2.fromScale(1.00099, 1),

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.fromRGB(113, 46, 206),
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.02,
                },

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0, 4),
                    BottomRightRadius = UDim.new(0, 4),
                    TopLeftRadius = UDim.new(0, 4),
                    TopRightRadius = UDim.new(0, 4),
                },
            },
        },

        create "Frame" {
            Name = "Timer",
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderColor3 = Color3.new(),
            BorderSizePixel = 0,
            Position = UDim2.new(0.498798, 0, 0.0635531, -10),
            Size = UDim2.fromScale(0.130317, 0.0825394),

            create "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
                AspectRatio = 4.34,
            },

            create "ImageLabel" {
                Name = "ImageLabel",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                Image = "rbxassetid://83025760843264",
                Position = UDim2.fromScale(0.863551, 0.259735),
                Size = UDim2.fromScale(0.0592586, 0.257182),
                ZIndex = 2,
            },

            create "TextLabel" {
                Name = "23",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                FontFace = Font.new(
                    "rbxasset://fonts/families/RobotoMono.json",
                    Enum.FontWeight.Bold,
                    Enum.FontStyle.Italic
                ),
                Position = UDim2.fromScale(0.5, 0.744823),
                Size = UDim2.fromScale(0.199943, 0.510354),
                Text = "5:00",
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 2,

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.new(1, 1, 1),
                    LineJoinMode = Enum.LineJoinMode.Miter,
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.015625,
                },
            },

            create "ImageLabel" {
                Name = "ImageLabel",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://83025760843264",
                Position = UDim2.fromScale(0.045263, 0.259735),
                Size = UDim2.fromScale(0.0592586, 0.257182),
                ZIndex = 2,
            },

            create "ImageLabel" {
                Name = "Purple_Background_Image",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Image = "rbxassetid://106909274584862",
                Position = UDim2.fromScale(-0.00560117, 0.5),
                Size = UDim2.fromScale(1.00099, 1),

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.fromRGB(113, 46, 206),
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.02,
                },

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0, 4),
                    BottomRightRadius = UDim.new(0, 4),
                    TopLeftRadius = UDim.new(0, 4),
                    TopRightRadius = UDim.new(0, 4),
                },
            },

            create "TextLabel" {
                Name = "KILLS",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                FontFace = Font.new(
                    "rbxasset://fonts/families/RobotoMono.json",
                    Enum.FontWeight.Regular,
                    Enum.FontStyle.Italic
                ),
                LayoutOrder = 1,
                Position = UDim2.fromScale(0.5, 0.256229),
                Size = UDim2.fromScale(0.216467, 0.495768),
                Text = "TIME",
                TextColor3 = Color3.fromRGB(107, 100, 237),
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 2,

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.fromRGB(107, 100, 237),
                    LineJoinMode = Enum.LineJoinMode.Miter,
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.015625,
                },
            },
        },

        create "Frame" {
            Name = "BossNotification",
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.5, 0.392704),
            Size = UDim2.fromOffset(301, 100),

            create "ImageLabel" {
                Name = "Purple_Background_Image",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.75,
                Image = "rbxassetid://106909274584862",
                ImageTransparency = 0.56,
                Position = UDim2.fromScale(-0.00560117, 0.5),
                Size = UDim2.fromScale(1.00099, 1),

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.fromRGB(113, 46, 206),
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.02,
                },

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0, 4),
                    BottomRightRadius = UDim.new(0, 4),
                    TopLeftRadius = UDim.new(0, 4),
                    TopRightRadius = UDim.new(0, 4),
                },
            },

            create "TextLabel" {
                Name = "KILLS",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                FontFace = Font.new(
                    "rbxasset://fonts/families/RobotoMono.json",
                    Enum.FontWeight.Bold,
                    Enum.FontStyle.Italic
                ),
                LayoutOrder = 1,
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(0.402513, 0.8503),
                Text = "BOSS INCOMING",
                TextColor3 = Color3.fromRGB(213, 0, 0),
                TextScaled = true,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 2,

                create "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.fromRGB(237, 0, 0),
                    LineJoinMode = Enum.LineJoinMode.Miter,
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.015625,
                },
            },

            create "ImageLabel" {
                Name = "ImageLabel",
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://121467172736704",
                Position = UDim2.new(0, 10, 0.5, 0),
                Size = UDim2.fromScale(0.14511, 0.629776),
                ZIndex = 2,
            },

            create "ImageLabel" {
                Name = "ImageLabel",
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://121467172736704",
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromScale(0.14511, 0.629776),
                ZIndex = 2,
            },
        },
    },
}