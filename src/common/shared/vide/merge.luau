local replicated_storage = game:GetService("ReplicatedStorage")

local vide = require(replicated_storage.Packages.vide)

local create = vide.create

local function Merge(): ScreenGui
    return create "ScreenGui" {
    Name = "Merge",
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

    create "Frame" {
        Name = "Parent_Frame",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderColor3 = Color3.new(),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.532295, 0.598214),

        create "ImageButton" {
            Name = "Merge",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(217, 14, 232),
            Image = "rbxassetid://6927295847",
            Position = UDim2.fromScale(0.784399, 0.895522),
            ScaleType = Enum.ScaleType.Tile,
            Size = UDim2.fromScale(0.347779, 0.149254),
            TileSize = UDim2.fromOffset(100, 100),

            create "TextLabel" {
                Name = "Merge_Text_Label",
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                Position = UDim2.fromScale(0.200689, 0.19),
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
        },

        create "ImageLabel" {
            Name = "Header_Background",
            BackgroundColor3 = Color3.fromRGB(166, 166, 166),
            Image = "rbxassetid://6927295847",
            Position = UDim2.fromScale(-0.0140463, 0),
            ScaleType = Enum.ScaleType.Tile,
            Size = UDim2.fromScale(1.01517, 0.141791),
            TileSize = UDim2.fromOffset(100, 100),

            create "TextLabel" {
                Name = "TextLabel",
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                Position = UDim2.fromScale(0.155292, 0.166167),
                RichText = true,
                Size = UDim2.fromScale(0.653148, 0.663158),
                Text = "Foundry",
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.0609756,
                },

                create "UIPadding" {
                    Name = "UIPadding",
                    PaddingBottom = UDim.new(-0.150794, 0),
                    PaddingTop = UDim.new(-0.150794, 0),
                },
            },

            create "UICorner" {
                Name = "UICorner",
                BottomLeftRadius = UDim.new(0.210526, 0),
                BottomRightRadius = UDim.new(0.210526, 0),
                TopLeftRadius = UDim.new(0.210526, 0),
                TopRightRadius = UDim.new(0.210526, 0),
            },
        },

        create "ImageButton" {
            Name = "X_Button",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(232, 0, 0),
            Image = "rbxassetid://6927295847",
            Position = UDim2.fromScale(0.944028, 0.0641791),
            ScaleType = Enum.ScaleType.Tile,
            Size = UDim2.fromScale(0.0747562, 0.113433),
            TileSize = UDim2.fromOffset(100, 100),

            create "TextLabel" {
                Name = "X_Text_Label",
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                Position = UDim2.fromScale(-0.958731, 0.163684),
                RichText = true,
                Size = UDim2.fromScale(2.89855, 0.657895),
                Text = "X",
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.0481928,
                },

                create "UIPadding" {
                    Name = "UIPadding",
                    PaddingBottom = UDim.new(-0.33, 0),
                    PaddingTop = UDim.new(-0.33, 0),
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
        },

        create "Frame" {
            Name = "Stats_Frame",
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.0119177, 0.153731),
            Size = UDim2.fromScale(0.264355, 0.623881),

            create "ImageLabel" {
                Name = "Stats_Stud_Image",
                BackgroundColor3 = Color3.fromRGB(189, 189, 189),
                Image = "rbxassetid://6927295847",
                ScaleType = Enum.ScaleType.Tile,
                Size = UDim2.fromScale(0.995902, 1),
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
            },

            create "ImageButton" {
                Name = "Gun_Button_21",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Image = "rbxassetid://122093144391590",
                Position = UDim2.fromScale(0.495216, 0.726989),
                Size = UDim2.fromScale(0.500651, 0.395364),

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0.13245, 0),
                    BottomRightRadius = UDim.new(0.13245, 0),
                    TopLeftRadius = UDim.new(0.13245, 0),
                    TopRightRadius = UDim.new(0.13245, 0),
                },

                create "UIAspectRatioConstraint" {
                    Name = "UIAspectRatioConstraint",
                },

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.0198676,
                },
            },

            create "ImageButton" {
                Name = "Gun_Button_21",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Image = "rbxassetid://122093144391590",
                Position = UDim2.fromScale(0.495216, 0.217385),
                Size = UDim2.fromScale(0.500651, 0.395364),

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0.13245, 0),
                    BottomRightRadius = UDim.new(0.13245, 0),
                    TopLeftRadius = UDim.new(0.13245, 0),
                    TopRightRadius = UDim.new(0.13245, 0),
                },

                create "UIAspectRatioConstraint" {
                    Name = "UIAspectRatioConstraint",
                },

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.0198676,
                },
            },
        },

        create "ImageLabel" {
            Name = "Black_Stud_Background",
            BackgroundColor3 = Color3.fromRGB(30, 30, 30),
            Image = "rbxassetid://6927295847",
            Position = UDim2.fromScale(-0.0140463, 0),
            ScaleType = Enum.ScaleType.Tile,
            Size = UDim2.fromScale(1.01517, 1),
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
        },

        create "ScrollingFrame" {
            Name = "ScrollingFrame",
            Active = true,
            BackgroundColor3 = Color3.fromRGB(255, 8, 0),
            BackgroundTransparency = 0.2,
            BorderColor3 = Color3.new(),
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.300108, 0.153731),
            ScrollBarImageColor3 = Color3.new(),
            Size = UDim2.fromScale(0.692308, 0.635821),

            create "ImageButton" {
                Name = "Gun_Button_11",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Image = "rbxassetid://83770969993177",
                Position = UDim2.fromScale(0.165884, 0.0682279),
                Size = UDim2.fromScale(0.258216, 0.123741),

                create "UIAspectRatioConstraint" {
                    Name = "UIAspectRatioConstraint",
                    AspectRatio = 0.972987,
                },

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.0198676,
                },

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0.13245, 0),
                    BottomRightRadius = UDim.new(0.13245, 0),
                    TopLeftRadius = UDim.new(0.13245, 0),
                    TopRightRadius = UDim.new(0.13245, 0),
                },
            },

            create "ImageButton" {
                Name = "Gun_Button_12",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Image = "rbxassetid://83770969993177",
                Position = UDim2.fromScale(0.475743, 0.0682279),
                Size = UDim2.fromScale(0.258216, 0.123399),

                create "UIAspectRatioConstraint" {
                    Name = "UIAspectRatioConstraint",
                    AspectRatio = 0.975681,
                },

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.0198676,
                },

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0.13245, 0),
                    BottomRightRadius = UDim.new(0.13245, 0),
                    TopLeftRadius = UDim.new(0.13245, 0),
                    TopRightRadius = UDim.new(0.13245, 0),
                },
            },

            create "ImageButton" {
                Name = "Gun_Button_13",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Image = "rbxassetid://83770969993177",
                Position = UDim2.fromScale(0.794992, 0.0682279),
                Size = UDim2.fromScale(0.258216, 0.123741),

                create "UIAspectRatioConstraint" {
                    Name = "UIAspectRatioConstraint",
                    AspectRatio = 0.972987,
                },

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.0198676,
                },

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0.13245, 0),
                    BottomRightRadius = UDim.new(0.13245, 0),
                    TopLeftRadius = UDim.new(0.13245, 0),
                    TopRightRadius = UDim.new(0.13245, 0),
                },
            },

            create "ImageButton" {
                Name = "Gun_Button_21",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Image = "rbxassetid://83770969993177",
                Position = UDim2.fromScale(0.165884, 0.211698),
                Size = UDim2.fromScale(0.258216, 0.12327),

                create "UIAspectRatioConstraint" {
                    Name = "UIAspectRatioConstraint",
                    AspectRatio = 0.9767,
                },

                create "UICorner" {
                    Name = "UICorner",
                    BottomLeftRadius = UDim.new(0.13245, 0),
                    BottomRightRadius = UDim.new(0.13245, 0),
                    TopLeftRadius = UDim.new(0.13245, 0),
                    TopRightRadius = UDim.new(0.13245, 0),
                },

                create "UIStroke" {
                    Name = "UIStroke",
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.0198676,
                },
            },

            create "UIStroke" {
                Name = "UIStroke",
                StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                Thickness = 0.0117371,
            },

            create "UICorner" {
                Name = "UICorner",
                BottomLeftRadius = UDim.new(0.0469484, 0),
                BottomRightRadius = UDim.new(0.0469484, 0),
                TopLeftRadius = UDim.new(0.0469484, 0),
                TopRightRadius = UDim.new(0.0469484, 0),
            },
        },
    },
    }
end

return Merge