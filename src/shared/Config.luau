-- All tunable game values in one place.
-- Adjust numbers here without touching any logic files.
return {
	-- Zombie
	ZOMBIE_MAX_HEALTH      = 50,
	ZOMBIE_WALK_SPEED      = 14,
	ZOMBIE_TOUCH_DAMAGE    = 10,
	ZOMBIE_DAMAGE_COOLDOWN = 1,    -- seconds between touch hits
	ZOMBIE_CHASE_INTERVAL  = 0.1,  -- how often MoveTo refreshes
	ZOMBIE_SPAWN_RADIUS    = 40,   -- max studs from map centre
	ZOMBIE_SPAWN_HEIGHT    = 3,    -- studs above ground

	-- Laser gun
	LASER_DAMAGE        = 25,
	LASER_RANGE         = 500,
	LASER_FIRE_COOLDOWN = 0.3,

	-- Wave progression
	WAVE_START_DELAY    = 3,
	WAVE_BETWEEN_DELAY  = 5,
	WAVE_SPAWN_INTERVAL = 1,

	-- Player movement
	PLAYER_WALK_SPEED   = 16,
	PLAYER_SPRINT_SPEED = 30,
	PLAYER_JUMP_POWER   = 70,
}
