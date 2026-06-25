--!strict
return {
	DATA_STORE_NAME = "PlayerStats",

	BOLT_RISE_DURATION        = 0.5,
	BOLT_HOVER_HEIGHT         = 0.1,
	BOLT_ATTRACT_RADIUS       = 20,
	BOLT_ATTRACT_ACCELERATION = 15,
	BOLT_COLLECT_RADIUS       = 3,

	SILVER_START_BALANCE = 0,
	SILVER_DROP_BY_ZOMBIE_TYPE = {
		Normal = { min = 2, max = 5 },
		Fast   = { min = 3, max = 6 },
		Tank   = { min = 5, max = 10 },
	},
	SILVER_WAVE_MULTIPLIER_STEP = 0.06,

	GOLD_DROP_BY_ZOMBIE_TYPE = {
		Normal = { chance = 0.035, min = 1, max = 3 },
		Fast   = { chance = 0.06,  min = 1, max = 4 },
		Tank   = { chance = 0.1,   min = 2, max = 6 },
	},
	GOLD_WAVE_CHANCE_STEP = 0.015,
	GOLD_WAVE_REWARD_STEP = 0.04,

	GOLD_WEAPON_UNLOCK_PRICES = {
		Deagle = 0,
		M82    = 0,
		M60    = 120,
		M240B  = 180,
		MG42   = 120,
		HandCannon = 160,
		MP5 = 0,
		SCAR = 0
	},
	SHOP_SILVER_PRICES = {
		ammoRefill  = 30,
		healthPack  = 55,
		damageBoost = 75,
		speedBoost  = 60,
	},
	SHOP_GUN_PRICES = {
		Deagle = 0,
		M82    = 0,
		M60    = 80,
		M240B  = 100,
		MG42   = 80,
		HandCannon = 0,
		MP5 = 0,
		SCAR = 0
	},
}
