--!strict

local replicated_storage = game:GetService("ReplicatedStorage")
local vide = require(replicated_storage.Packages.vide)

export type ColorSources = {
	black: vide.Source<Color3>,
	white: vide.Source<Color3>,
	grey: vide.Source<Color3>,
	purple: vide.Source<Color3>,
	purpleStroke: vide.Source<Color3>,
	xpGradientStart: vide.Source<Color3>,
	xpGradientEnd: vide.Source<Color3>,
	bossRed: vide.Source<Color3>,
	bossStrokeRed: vide.Source<Color3>,
}

export type Skill = {
	name: string,
	image: string,
}

return {}
