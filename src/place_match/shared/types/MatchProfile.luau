--!strict
local MatchProfile = {}

export type GunModifer = {
	reload_speed: number,
	ammo_capacity: number,
	damage: number,
	fire_rate: number
}

export type PlayerModifier = {
	health: number,
	speed: number,
}

export type FlatModifiers = { [string]: number }

export type MatchProfile = {
	gun_modifier: GunModifer,
	player_modifier: PlayerModifier,
}

function MatchProfile.into(profile: MatchProfile): FlatModifiers
	local modifiers: FlatModifiers = {}

	for property, value in pairs(profile.gun_modifier) do
		modifiers[property] = value
	end

	for property, value in pairs(profile.player_modifier) do
		modifiers[property] = value
	end

	return modifiers
end

return MatchProfile