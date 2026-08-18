local replicated_storage = game:GetService("ReplicatedStorage")
local vide = require(replicated_storage.Packages.vide)

local components = script.Parent.match_hud_components
local HealthBar = require(components.health_bar)
local KillsCoins = require(components.kills_coins)
local SkillsTree = require(components.skills_tree)
local Timer = require(components.timer)
local WeaponTiles = require(components.weapon_tiles)
local XpBar = require(components.xp_bar)
local ComponentTypes = require(components.component_types)
local SkillTypes = require(replicated_storage.match.shared.types.skill_types)
local WaveConfig = require(replicated_storage.match.shared.configs.wave_config)
local create = vide.create
local root = vide.root
local source = vide.source

local colors = {
	black = source(Color3.new()),
	white = source(Color3.new(1, 1, 1)),
	grey = source(Color3.fromRGB(35, 35, 35)),
	purple = source(Color3.fromRGB(107, 100, 237)),
	purpleStroke = source(Color3.fromRGB(113, 46, 206)),
	xpGradientStart = source(Color3.fromRGB(64, 60, 141)),
	xpGradientEnd = source(Color3.fromRGB(112, 107, 255)),
	bossRed = source(Color3.fromRGB(213, 0, 0)),
	bossStrokeRed = source(Color3.fromRGB(237, 0, 0)),
}

local healthPercent = source(76)
local currentXP = source(100)
local requiredXP = source(1000)
local xpPercent = source(0.3)
local timerSeconds = source(WaveConfig.BATTLE_DURATION)
local kills = source(0)
local coins = source(0)
local ammoTextByGun = source({} :: { [string]: string })
local ammoColorByGun = source({} :: { [string]: Color3 })
local skills = source({} :: SkillTypes.OwnedSkills)
local guns = source({} :: { WeaponTiles.GunSlot })

local destroyRoot, matchHud = root(function()
	return create "ScreenGui" {
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

			SkillsTree({
				colors = colors,
				skills = skills,
			}),

			HealthBar({
				colors = colors,
				healthPercent = healthPercent,
			}),

			XpBar({
				colors = colors,
				currentXP = currentXP,
				requiredXP = requiredXP,
				xpPercent = xpPercent,
			}),

			WeaponTiles({
				ammoColorByGun = ammoColorByGun,
				ammoTextByGun = ammoTextByGun,
				colors = colors,
				guns = guns,
			}),

			KillsCoins({
				coins = coins,
				colors = colors,
				kills = kills,
			}),

			Timer({
				colors = colors,
				seconds = timerSeconds,
			}),

			-- create "Frame" {
			-- 	Name = "BossNotification",
			-- 	AnchorPoint = Vector2.new(0.5, 0),
			-- 	BackgroundTransparency = 1,
			-- 	Position = UDim2.fromScale(0.5, 0.392704),
			-- 	Size = UDim2.fromOffset(301, 100),

			-- 	create "ImageLabel" {
			-- 		Name = "Purple_Background_Image",
			-- 		AnchorPoint = Vector2.new(0, 0.5),
			-- 		BackgroundColor3 = colors.white,
			-- 		BackgroundTransparency = 0.75,
			-- 		Image = "rbxassetid://106909274584862",
			-- 		ImageColor3 = colors.white,
			-- 		ImageTransparency = 0.56,
			-- 		Position = UDim2.fromScale(-0.00560117, 0.5),
			-- 		Size = UDim2.fromScale(1.00099, 1),

			-- 		create "UIStroke" {
			-- 			Name = "UIStroke",
			-- 			Color = colors.purpleStroke,
			-- 			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			-- 			Thickness = 0.02,
			-- 		},

			-- 		create "UICorner" {
			-- 			Name = "UICorner",
			-- 			BottomLeftRadius = UDim.new(0, 4),
			-- 			BottomRightRadius = UDim.new(0, 4),
			-- 			TopLeftRadius = UDim.new(0, 4),
			-- 			TopRightRadius = UDim.new(0, 4),
			-- 		},
			-- 	},

			-- 	create "TextLabel" {
			-- 		Name = "KILLS",
			-- 		AnchorPoint = Vector2.new(0.5, 0.5),
			-- 		BackgroundTransparency = 1,
			-- 		FontFace = Font.new(
			-- 			"rbxasset://fonts/families/RobotoMono.json",
			-- 			Enum.FontWeight.Bold,
			-- 			Enum.FontStyle.Italic
			-- 		),
			-- 		LayoutOrder = 1,
			-- 		Position = UDim2.fromScale(0.5, 0.5),
			-- 		Size = UDim2.fromScale(0.402513, 0.8503),
			-- 		Text = "BOSS INCOMING",
			-- 		TextColor3 = colors.bossRed,
			-- 		TextScaled = true,
			-- 		TextYAlignment = Enum.TextYAlignment.Top,
			-- 		ZIndex = 2,

			-- 		create "UIStroke" {
			-- 			Name = "UIStroke",
			-- 			Color = colors.bossStrokeRed,
			-- 			LineJoinMode = Enum.LineJoinMode.Miter,
			-- 			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			-- 			Thickness = 0.015625,
			-- 		},
			-- 	},

			-- 	create "ImageLabel" {
			-- 		Name = "ImageLabel",
			-- 		AnchorPoint = Vector2.new(0, 0.5),
			-- 		BackgroundTransparency = 1,
			-- 		Image = "rbxassetid://121467172736704",
			-- 		ImageColor3 = colors.white,
			-- 		Position = UDim2.new(0, 10, 0.5, 0),
			-- 		Size = UDim2.fromScale(0.14511, 0.629776),
			-- 		ZIndex = 2,
			-- 	},

			-- 	create "ImageLabel" {
			-- 		Name = "ImageLabel",
			-- 		AnchorPoint = Vector2.new(1, 0.5),
			-- 		BackgroundTransparency = 1,
			-- 		Image = "rbxassetid://121467172736704",
			-- 		ImageColor3 = colors.white,
			-- 		Position = UDim2.new(1, -10, 0.5, 0),
			-- 		Size = UDim2.fromScale(0.14511, 0.629776),
			-- 		ZIndex = 2,
			-- 	},
			-- },
		},
	}
end)

matchHud.Destroying:Once(destroyRoot)

return {
	gui = matchHud,
	sources = {
		ammoColorByGun = ammoColorByGun,
		ammoTextByGun = ammoTextByGun,
		colors = colors,
		coins = coins,
		currentXP = currentXP,
		healthPercent = healthPercent,
		kills = kills,
		requiredXP = requiredXP,
		guns = guns,
		skills = skills,
		timerSeconds = timerSeconds,
		xpPercent = xpPercent,
	},
}
