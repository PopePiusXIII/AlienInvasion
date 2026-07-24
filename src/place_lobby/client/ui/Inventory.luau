local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide  = require(ReplicatedStorage.Packages.vide)
local DepressedButton = require(ReplicatedStorage.Shared.vide.DepressedButton)

local create = vide.create

local inventoryRoot = create "ScreenGui" {
    Name = "OpenedInventory",
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}


local main_frame = create "Frame" {
    Name = "Parent_Frame",
    Parent = inventoryRoot,
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Position = UDim2.fromScale(0.516218, 0.499151),
    Size = UDim2.fromScale(0.723221, 0.745365),


    create "ImageButton" {
        Name = "Merge",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(217, 14, 232),
        Image = "rbxassetid://6927295847",
        Position = UDim2.fromScale(0.782492, 0.901529),
        ScaleType = Enum.ScaleType.Tile,
        Size = UDim2.fromScale(0.344791, 0.14708),
        TileSize = UDim2.fromOffset(100, 100),

        create "TextLabel" {
            Name = "Merge_Text_Label",
            BackgroundTransparency = 1,
            FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
            Position = UDim2.fromScale(0.188474, 0.25),
            RichText = true,
            Size = UDim2.fromScale(0.623053, 0.5),
            Text = "Merge",
            TextColor3 = Color3.new(1, 1, 1),
            TextScaled = true,

            create "UIStroke" {
                Name = "UIStroke",
                StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                Thickness = 0.0512821,
            },

            create "UIPadding" {
                Name = "UIPadding",
                PaddingBottom = UDim.new(-0.5, 0),
                PaddingTop = UDim.new(-0.5, 0),
            },

            create "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
                AspectRatio = 4,
            },
        },

        create "UICorner" {
            Name = "UICorner",
            BottomLeftRadius = UDim.new(0.2, 0),
            BottomRightRadius = UDim.new(0.2, 0),
            TopLeftRadius = UDim.new(0.2, 0),
            TopRightRadius = UDim.new(0.2, 0),
        },

        create "UIStroke" {
            Name = "UIStroke",
            StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
            Thickness = 0.05,
        },

        create "UIGradient" {
            Name = "UIGradient",
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 15, 251)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 15, 251)),
            }),
        },

        create "UIAspectRatioConstraint" {
            Name = "UIAspectRatioConstraint",
            AspectRatio = 3.21,
        },
    },

    create "ImageLabel" {
        Name = "Header_Background",
        BackgroundColor3 = Color3.fromRGB(166, 166, 166),
        Image = "rbxassetid://6927295847",
        Position = UDim2.fromScale(0.0102041, 0.00654554),
        ScaleType = Enum.ScaleType.Tile,
        Size = UDim2.fromScale(0.979592, 0.139726),
        TileSize = UDim2.fromOffset(100, 100),

        create "TextLabel" {
            Name = "TextLabel",
            BackgroundTransparency = 1,
            FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
            Position = UDim2.fromScale(0.164474, 0.168421),
            RichText = true,
            Size = UDim2.fromScale(0.671053, 0.663158),
            Text = "Weapon Inventory",
            TextColor3 = Color3.new(1, 1, 1),
            TextScaled = true,

            create "UIStroke" {
                Name = "UIStroke",
                StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                Thickness = 0.0609756,
            },

            create "UIPadding" {
                Name = "UIPadding",
                PaddingBottom = UDim.new(-0.15873, 0),
                PaddingTop = UDim.new(-0.15873, 0),
            },

            create "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
                AspectRatio = 9.71429,
            },
        },

        create "UICorner" {
            Name = "UICorner",
            BottomLeftRadius = UDim.new(0.210526, 0),
            BottomRightRadius = UDim.new(0.210526, 0),
            TopLeftRadius = UDim.new(0.210526, 0),
            TopRightRadius = UDim.new(0.210526, 0),
        },

        create "UIAspectRatioConstraint" {
            Name = "UIAspectRatioConstraint",
            AspectRatio = 9.6,
        },
    },

    create "ImageButton" {
        Name = "X_Button",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(232, 0, 0),
        Image = "rbxassetid://6927295847",
        Position = UDim2.fromScale(0.952202, 0.0631715),
        ScaleType = Enum.ScaleType.Tile,
        Size = UDim2.fromScale(0.0741139, 0.111781),
        TileSize = UDim2.fromOffset(100, 100),

        create "TextLabel" {
            Name = "X_Text_Label",
            BackgroundTransparency = 1,
            FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
            Position = UDim2.fromScale(-0.949275, 0.171053),
            RichText = true,
            Size = UDim2.fromScale(2.89855, 0.657895),
            Text = "X",
            TextColor3 = Color3.new(1, 1, 1),
            TextScaled = true,

            create "UIStroke" {
                Name = "UIStroke",
                StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                Thickness = 0.047619,
            },

            create "UIPadding" {
                Name = "UIPadding",
                PaddingBottom = UDim.new(-0.34, 0),
                PaddingTop = UDim.new(-0.34, 0),
            },

            create "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
                AspectRatio = 4,
            },
        },

        create "UICorner" {
            Name = "UICorner",
            BottomLeftRadius = UDim.new(0.289855, 0),
            BottomRightRadius = UDim.new(0.289855, 0),
            TopLeftRadius = UDim.new(0.289855, 0),
            TopRightRadius = UDim.new(0.289855, 0),
        },

        create "UIStroke" {
            Name = "UIStroke",
            StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
            Thickness = 0.0724638,
        },

        create "UIGradient" {
            Name = "UIGradient",
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 15, 251)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 15, 251)),
            }),
        },

        create "UIAspectRatioConstraint" {
            Name = "UIAspectRatioConstraint",
            AspectRatio = 0.907895,
        },
    },

    create "Frame" {
        Name = "Stats_Frame",
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.368958, 0.192602),
        Size = UDim2.fromScale(0.262084, 0.614796),

        create "ImageLabel" {
            Name = "Stats_Stud_Image",
            BackgroundColor3 = Color3.fromRGB(189, 189, 189),
            Image = "rbxassetid://6927295847",
            Position = UDim2.fromScale(-1.28788, -0.0191388),
            ScaleType = Enum.ScaleType.Tile,
            Size = UDim2.fromScale(1.07361, 0.970774),
            TileSize = UDim2.fromOffset(100, 100),

            create "UICorner" {
                Name = "UICorner",
                BottomLeftRadius = UDim.new(0.0823045, 0),
                BottomRightRadius = UDim.new(0.0823045, 0),
                TopLeftRadius = UDim.new(0.0823045, 0),
                TopRightRadius = UDim.new(0.0823045, 0),
            },

            create "UIStroke" {
                Name = "UIStroke",
                StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                Thickness = 0.0205761,
            },

            create "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
                AspectRatio = 0.58134,
            },
        },

        create "ImageLabel" {
            Name = "Gun_Stats_Image",
            BackgroundColor3 = Color3.new(1, 1, 1),
            Image = "rbxassetid://83770969993177",
            Position = UDim2.fromScale(-1.10527, -0.000752301),
            Size = UDim2.fromScale(0.610656, 0.356459),

            create "UIStroke" {
                Name = "UIStroke",
                StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                Thickness = 0.0201342,
            },

            create "UICorner" {
                Name = "UICorner",
                BottomLeftRadius = UDim.new(0.134228, 0),
                BottomRightRadius = UDim.new(0.134228, 0),
                TopLeftRadius = UDim.new(0.134228, 0),
                TopRightRadius = UDim.new(0.134228, 0),
            },

            create "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
            },
        },

        create "Frame" {
            Name = "Stats_Property_Frame",
            BackgroundColor3 = Color3.fromRGB(30, 30, 30),
            Position = UDim2.fromScale(-1.21721, 0.407895),
            Size = UDim2.fromScale(0.827869, 0.466507),

            create "TextLabel" {
                Name = "Text_1_top",
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                Position = UDim2.fromScale(0.00990099, -0.0025641),
                RichText = true,
                Size = UDim2.fromScale(0.990099, 0.25641),
                Text = "Property - Stat",
                TextColor3 = Color3.fromRGB(254, 254, 254),
                TextScaled = true,

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.105263,
                },

                create "UIPadding" {
                    Name = "UIPadding",
                    PaddingBottom = UDim.new(0.3, 0),
                    PaddingTop = UDim.new(0.3, 0),
                },

                create "UIAspectRatioConstraint" {
                    Name = "UIAspectRatioConstraint",
                    AspectRatio = 4,
                },
            },

            create "TextLabel" {
                Name = "Text_2",
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                Position = UDim2.fromScale(0.00990099, 0.253846),
                RichText = true,
                Size = UDim2.fromScale(0.990099, 0.25641),
                Text = "Property - Stat",
                TextColor3 = Color3.fromRGB(254, 254, 254),
                TextScaled = true,

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.105263,
                },

                create "UIPadding" {
                    Name = "UIPadding",
                    PaddingBottom = UDim.new(0.3, 0),
                    PaddingTop = UDim.new(0.3, 0),
                },

                create "UIAspectRatioConstraint" {
                    Name = "UIAspectRatioConstraint",
                    AspectRatio = 4,
                },
            },

            create "TextLabel" {
                Name = "Text_3",
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                Position = UDim2.fromScale(0.0049505, 0.507692),
                RichText = true,
                Size = UDim2.fromScale(0.990099, 0.230769),
                Text = "Property - Stat",
                TextColor3 = Color3.fromRGB(254, 254, 254),
                TextScaled = true,

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.105263,
                },

                create "UIPadding" {
                    Name = "UIPadding",
                    PaddingBottom = UDim.new(0.288889, 0),
                    PaddingTop = UDim.new(0.288889, 0),
                },

                create "UIAspectRatioConstraint" {
                    Name = "UIAspectRatioConstraint",
                    AspectRatio = 4.44444,
                },
            },

            create "TextLabel" {
                Name = "Text_4_bottom",
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                Position = UDim2.fromScale(0.00990099, 0.741026),
                RichText = true,
                Size = UDim2.fromScale(0.990099, 0.25641),
                Text = "Property - Stat",
                TextColor3 = Color3.fromRGB(254, 254, 254),
                TextScaled = true,

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.105263,
                },

                create "UIPadding" {
                    Name = "UIPadding",
                    PaddingBottom = UDim.new(0.3, 0),
                    PaddingTop = UDim.new(0.3, 0),
                },

                create "UIAspectRatioConstraint" {
                    Name = "UIAspectRatioConstraint",
                    AspectRatio = 4,
                },
            },

            create "UICorner" {
                Name = "UICorner",
                BottomLeftRadius = UDim.new(0.0512821, 0),
                BottomRightRadius = UDim.new(0.0512821, 0),
                TopLeftRadius = UDim.new(0.0512821, 0),
                TopRightRadius = UDim.new(0.0512821, 0),
            },

            create "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
                AspectRatio = 1.0359,
            },
        },

        create "UIAspectRatioConstraint" {
            Name = "UIAspectRatioConstraint",
            AspectRatio = 0.583732,
        },
    },

    create "ImageLabel" {
        Name = "Black_Stud_Background",
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        Image = "rbxassetid://6927295847",
        Position = UDim2.fromScale(0.010204, 0.00608306),
        ScaleType = Enum.ScaleType.Tile,
        Size = UDim2.fromScale(0.979592, 0.985438),
        TileSize = UDim2.fromOffset(100, 100),
        ZIndex = 0,

        create "UICorner" {
            Name = "UICorner",
            BottomLeftRadius = UDim.new(0.0298507, 0),
            BottomRightRadius = UDim.new(0.0298507, 0),
            TopLeftRadius = UDim.new(0.0298507, 0),
            TopRightRadius = UDim.new(0.0298507, 0),
        },

        create "UIStroke" {
            Name = "UIStroke",
            StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
            Thickness = 0.0149254,
        },

        create "UIAspectRatioConstraint" {
            Name = "UIAspectRatioConstraint",
            AspectRatio = 1.36119,
        },
    },

    create "UIAspectRatioConstraint" {
        Name = "UIAspectRatioConstraint",
        AspectRatio = 1.36932,
    },
}

------------------------------------------------------scrolling frame -----------------------------------------------------------

local scrolling: ScrollingFrame = create "ScrollingFrame" {
            Name = "ScrollingFrame",
            Parent = main_frame,
            Active = true,
            BackgroundColor3 = Color3.fromRGB(255, 8, 0),
            BackgroundTransparency = 0.2,
            BorderColor3 = Color3.new(),
            BorderSizePixel = 0,
            CanvasSize = UDim2.fromScale(0, 2.00029),
            Position = UDim2.fromScale(0.3029, 0.181717),
            ScrollBarImageColor3 = Color3.new(),
            Size = UDim2.fromScale(0.686359, 0.615975),

            create "UICorner" {
                Name = "UICorner",
                BottomLeftRadius = UDim.new(0.0477553, 0),
                BottomRightRadius = UDim.new(0.0477553, 0),
                TopLeftRadius = UDim.new(0.0477553, 0),
                TopRightRadius = UDim.new(0.0477553, 0),
            },

            create "UIStroke" {
                Name = "UIStroke",
                StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                Thickness = 0.0119388,
            },
            create "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
                AspectRatio = 1.52578,
            },
        }

DepressedButton({
    parent = scrolling,
    image    = "rbxassetid://83770969993177",
    position = UDim2.fromScale(0.820814, 0.0611586),
    size = UDim2.fromScale(0.258216, 0.111029),
    hoverSoundId = "",
    onActivated = function()
        print("HI")
    end,

    -- create "UIStroke" {
    --     Name = "UIStroke",
    --     StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
    --     Thickness = 0.0198676,
    -- },

    -- create "UICorner" {
    --     Name = "UICorner",
    --     BottomLeftRadius = UDim.new(0.13245, 0),
    --     BottomRightRadius = UDim.new(0.13245, 0),
    --     TopLeftRadius = UDim.new(0.13245, 0),
    --     TopRightRadius = UDim.new(0.13245, 0),
    -- },

    -- create "UIAspectRatioConstraint" {
    --     Name = "UIAspectRatioConstraint",
    --     AspectRatio = 1.09272,
    -- }
            
    })
---------------------------------------------------------------------------------------------------------------------------------


return inventoryRoot
