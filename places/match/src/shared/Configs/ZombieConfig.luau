--!strict
return {
	ZOMBIE_TYPES = {
		Normal  = { MaxHealth = 50,  WalkSpeed = 14, TouchDamage = 10, Template = "Normal_Zombie"  },
		Tank    = { MaxHealth = 250, WalkSpeed = 6,  TouchDamage = 25, Template = "Tank_Zombie"    },
	},
	ZOMBIE_DEFAULT_TYPE    = "Normal",
	ZOMBIE_DAMAGE_COOLDOWN = 1,
	ZOMBIE_CHASE_INTERVAL  = 0.3,
	ZOMBIE_SPAWN_DISTANCE  = 100,
	ZOMBIE_SPAWN_HEIGHT    = 3,
}
