--!strict
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

export type MatchProfileT = {
	gun_modifier: GunModifer,
	player_modifier: PlayerModifier,
}

return {}