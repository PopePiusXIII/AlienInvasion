--!strict
return {
	ZOMBIE_TYPES = {
		Normal  = {
			MaxHealth = 50,
			WalkSpeed = 14,
			TouchDamage = 10,
			Template = "Normal_Zombie",
			-- Optional Animations table. If present, keys are action names and values
			-- are Roblox asset ids (number or string). Example:
			Animations = { walk = 180426354, jump = 125750702 }
		},
		Normal_Run  = {
			MaxHealth = 50,
			WalkSpeed = 30,
			TouchDamage = 10,
			Template = "Normal_Run_Zombie",
			-- Optional Animations table. If present, keys are action names and values
			-- are Roblox asset ids (number or string). Example:
			Animations = { walk = 180426354, jump = 125750702 }
		},
		Tank    = {
			MaxHealth = 250,
			WalkSpeed = 6,
			TouchDamage = 25,
			Template = "Tank_Zombie",
			Animations = {},
		},
	},
	ZOMBIE_DEFAULT_TYPE    = "Normal",
	ZOMBIE_DAMAGE_COOLDOWN     = 1,
	ZOMBIE_CHASE_INTERVAL      = 0.1,
	ZOMBIE_SPAWN_DISTANCE      = 100,
	ZOMBIE_SPAWN_HEIGHT        = 3,
	ZOMBIE_REPULSION_DISTANCE  = 8,   -- studs; zombies within this range push apart
	ZOMBIE_REPULSION_FORCE     = 14,  -- max offset (studs) applied to MoveTo target
}
