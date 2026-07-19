local ReplicatedStorage = (game.ReplicatedStorage)
local vide  = require(ReplicatedStorage.Packages.vide)
local DepressedButton = require(ReplicatedStorage.Shared.vide.DepressedButton)

local create = vide.create
local source = vide.source
local effect = vide.effect
local mount  = vide.mount

local inventoryRoot = create "Frame" {
    Name = "Parent_Frame",
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderColor3 = Color3.new(),
    BorderSizePixel = 0,
    Position = UDim2.fromScale(0.223011, 0.203571),
    Size = UDim2.fromOffset(923, 670),

    create "ImageLabel" {
        Name = "Black_Stud_Background",
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        Image = "rbxassetid://6927295847",
        Position = UDim2.fromScale(-0.0140463, 0),
        ScaleType = Enum.ScaleType.Tile,
        Size = UDim2.fromOffset(937, 670),
        TileSize = UDim2.fromOffset(100, 100),

        create "UICorner" {
            Name = "UICorner",
            BottomLeftRadius = UDim.new(0, 20),
            BottomRightRadius = UDim.new(0, 20),
            TopLeftRadius = UDim.new(0, 20),
            TopRightRadius = UDim.new(0, 20),
        },

        create "UIStroke" {
            Name = "UIStroke",
            Thickness = 10,
        },
    },

    create "ImageButton" {
        Name = "Merge",
        BackgroundColor3 = Color3.fromRGB(217, 14, 232),
        Image = "rbxassetid://6927295847",
        Position = UDim2.fromScale(0.638137, 0.81791),
        ScaleType = Enum.ScaleType.Tile,
        Size = UDim2.fromOffset(321, 100),
        TileSize = UDim2.fromOffset(100, 100),

        create "TextLabel" {
            Name = "Merge_Text_Label",
            BackgroundTransparency = 1,
            FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
            Position = UDim2.fromScale(0.200689, 0.19),
            Size = UDim2.fromOffset(200, 50),
            Text = "Merge",
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 100,

            create "UIStroke" {
                Name = "UIStroke",
                Thickness = 4,
            },
        },

        create "UICorner" {
            Name = "UICorner",
            BottomLeftRadius = UDim.new(0, 20),
            BottomRightRadius = UDim.new(0, 20),
            TopLeftRadius = UDim.new(0, 20),
            TopRightRadius = UDim.new(0, 20),
        },

        create "UIStroke" {
            Name = "UIStroke",
            Thickness = 5,
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
        Size = UDim2.fromOffset(937, 95),
        TileSize = UDim2.fromOffset(100, 100),

        create "TextLabel" {
            Name = "TextLabel",
            BackgroundTransparency = 1,
            FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
            Position = UDim2.fromScale(0.155292, 0.0603998),
            Size = UDim2.fromOffset(612, 63),
            Text = "Weapon Inventory",
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 82,
            TextWrapped = true,

            create "UIStroke" {
                Name = "UIStroke",
                Thickness = 5,
            },
        },

        create "UICorner" {
            Name = "UICorner",
            BottomLeftRadius = UDim.new(0, 20),
            BottomRightRadius = UDim.new(0, 20),
            TopLeftRadius = UDim.new(0, 20),
            TopRightRadius = UDim.new(0, 20),
        },
    },

    create "ImageButton" {
        Name = "X_Button",
        BackgroundColor3 = Color3.fromRGB(232, 0, 0),
        Image = "rbxassetid://6927295847",
        Position = UDim2.fromScale(0.911525, 0.00746269),
        ScaleType = Enum.ScaleType.Tile,
        Size = UDim2.fromOffset(69, 76),
        TileSize = UDim2.fromOffset(100, 100),

        create "TextLabel" {
            Name = "X_Text_Label",
            BackgroundTransparency = 1,
            FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
            Position = UDim2.fromScale(-0.958731, 0.163684),
            Size = UDim2.fromOffset(200, 50),
            Text = "X",
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 83,

            create "UIStroke" {
                Name = "UIStroke",
                Thickness = 4,
            },
        },

        create "UICorner" {
            Name = "UICorner",
            BottomLeftRadius = UDim.new(0, 20),
            BottomRightRadius = UDim.new(0, 20),
            TopLeftRadius = UDim.new(0, 20),
            TopRightRadius = UDim.new(0, 20),
        },

        create "UIStroke" {
            Name = "UIStroke",
            Thickness = 5,
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
        Size = UDim2.fromOffset(244, 418),

        create "ImageLabel" {
            Name = "Stats_Stud_Image",
            BackgroundColor3 = Color3.fromRGB(189, 189, 189),
            Image = "rbxassetid://6927295847",
            ScaleType = Enum.ScaleType.Tile,
            Size = UDim2.fromOffset(243, 418),
            TileSize = UDim2.fromOffset(100, 100),

            create "UICorner" {
                Name = "UICorner",
                BottomLeftRadius = UDim.new(0, 20),
                BottomRightRadius = UDim.new(0, 20),
                TopLeftRadius = UDim.new(0, 20),
                TopRightRadius = UDim.new(0, 20),
            },

            create "UIStroke" {
                Name = "UIStroke",
                Thickness = 5,
            },
        },

        create "ImageLabel" {
            Name = "Gun_Stats_Image",
            BackgroundColor3 = Color3.new(1, 1, 1),
            Image = "rbxassetid://83770969993177",
            Position = UDim2.fromScale(0.214559, 0.0239234),
            Size = UDim2.fromOffset(149, 149),

            create "UIStroke" {
                Name = "UIStroke",
                Thickness = 3,
            },

            create "UICorner" {
                Name = "UICorner",
                BottomLeftRadius = UDim.new(0, 20),
                BottomRightRadius = UDim.new(0, 20),
                TopLeftRadius = UDim.new(0, 20),
                TopRightRadius = UDim.new(0, 20),
            },
        },

        create "Frame" {
            Name = "Stats_Property_Frame",
            BackgroundColor3 = Color3.fromRGB(30, 30, 30),
            Position = UDim2.fromScale(0.0819672, 0.42823),
            Size = UDim2.fromOffset(202, 195),

            create "TextLabel" {
                Name = "Text_1_top",
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                Size = UDim2.fromOffset(200, 50),
                Text = "Property - Stat",
                TextColor3 = Color3.fromRGB(254, 254, 254),
                TextSize = 20,

                create "UIStroke" {
                    Name = "UIStroke",
                    Thickness = 2,
                },
            },

            create "TextLabel" {
                Name = "Text_2",
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                Position = UDim2.fromScale(0, 0.25641),
                Size = UDim2.fromOffset(200, 50),
                Text = "Property - Stat",
                TextColor3 = Color3.fromRGB(254, 254, 254),
                TextSize = 20,

                create "UIStroke" {
                    Name = "UIStroke",
                    Thickness = 2,
                },
            },

            create "TextLabel" {
                Name = "Text_3",
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                Position = UDim2.fromScale(0.00990099, 0.769231),
                Size = UDim2.fromOffset(200, 45),
                Text = "Property - Stat",
                TextColor3 = Color3.fromRGB(254, 254, 254),
                TextSize = 20,

                create "UIStroke" {
                    Name = "UIStroke",
                    Thickness = 2,
                },
            },

            create "TextLabel" {
                Name = "Text_4_bottom",
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                Position = UDim2.fromScale(0.00990099, 0.512821),
                Size = UDim2.fromOffset(200, 50),
                Text = "Property - Stat",
                TextColor3 = Color3.fromRGB(254, 254, 254),
                TextSize = 20,

                create "UIStroke" {
                    Name = "UIStroke",
                    Thickness = 2,
                },
            },

            create "UICorner" {
                Name = "UICorner",
                BottomLeftRadius = UDim.new(0, 10),
                BottomRightRadius = UDim.new(0, 10),
                TopLeftRadius = UDim.new(0, 10),
                TopRightRadius = UDim.new(0, 10),
            },
        },
    },
}




------------------------------------------------------scrolling frame -----------------------------------------------------------

local scrolling: ScrollingFrame = create "ScrollingFrame" {
        Name = "ScrollingFrame",
        Parent = inventoryRoot,
        Active = true,
        BackgroundColor3 = Color3.fromRGB(255, 8, 0),
        BackgroundTransparency = 0.2,
        BorderColor3 = Color3.new(),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.300108, 0.153731),
        ScrollBarImageColor3 = Color3.new(),
        Size = UDim2.fromOffset(639, 426),
        
        create "UICorner" {
            Name = "UICorner",
            BottomLeftRadius = UDim.new(0, 10),
            BottomRightRadius = UDim.new(0, 10),
            TopLeftRadius = UDim.new(0, 10),
            TopRightRadius = UDim.new(0, 10),
        },
        create "UIStroke" {
            Name = "UIStroke",
            Thickness = 5,
        },
    }

DepressedButton({
    parent = scrolling,
    image    = "rbxassetid://83770969993177",
    position = UDim2.fromScale(0.165884, 0.0619403),
    size = UDim2.fromOffset(165, 151),    
    hoverSoundId = "",
    onActivated = function()
        print("HI")
    end,
    })
---------------------------------------------------------------------------------------------------------------------------------


return inventoryRoot
