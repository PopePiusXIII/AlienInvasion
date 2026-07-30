--!strict
local SkillProfile = {}

export type GunModifier = {
	reload_speed: number,
	ammo_capacity: number,
	damage: number,
	fire_rate: number,
}

export type PlayerModifier = {
	health: number,
	speed: number,
}

export type ModifierOptions = { string } -- Array of strings

export type SkillProfile = {
	gun_modifier: GunModifier,
	player_modifier: PlayerModifier,
}

function SkillProfile.into(profile: SkillProfile): ModifierOptions
	local modifiers: ModifierOptions = {}

	for property:string, value:number in pairs(profile.gun_modifier) do
		table.insert(modifiers, property)
	end

	return modifiers
end

return SkillProfile