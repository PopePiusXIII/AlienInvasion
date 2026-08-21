--!strict

export type CueEntry = {
	zombieType: string,
	spawnPointName: string,
	amount: number,
}

export type WeightedCueEntry = {
	zombieType: string,
	spawnPointName: string,
	amount: number,
	weight: number,
}

export type Tier = {
	startTimeSeconds: number,
	maxAlive: number,
	entryCue: { CueEntry },
	randomCue: { WeightedCueEntry },
}

export type Level = {
	id: string,
	tiers: { Tier },
}

local MountainPass_1: Level = {
	id = "MountainPass_1",
	tiers = {
		{
			startTimeSeconds = 0,
			maxAlive = 10,
			entryCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 10 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_2", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_3", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_4", amount = 1, weight = 1 },
			},
		},
		{
			startTimeSeconds = 30,
			maxAlive = 25,
			entryCue = {
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob_2", amount = 25 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
			},
		},
		{
			startTimeSeconds = 60,
			maxAlive = 20,
			entryCue = {
				{ zombieType = "Tank", spawnPointName = "Spawn_Mob", amount = 2 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Tank", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
			},
		},
	}
}

local MountainPass_2: Level = {
	id = "MountainPass_2",
	tiers = {
		{
			startTimeSeconds = 0,
			maxAlive = 10,
			entryCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 10 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_2", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_3", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_4", amount = 1, weight = 1 },
			},
		},
		{
			startTimeSeconds = 30,
			maxAlive = 25,
			entryCue = {
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob_2", amount = 25 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
			},
		},
		{
			startTimeSeconds = 60,
			maxAlive = 20,
			entryCue = {
				{ zombieType = "Tank", spawnPointName = "Spawn_Mob", amount = 2 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Tank", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
			},
		},
	}
}

local MountainPass_3: Level = {
	id = "MountainPass_3",
	tiers = {
		{
			startTimeSeconds = 0,
			maxAlive = 10,
			entryCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 10 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_2", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_3", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_4", amount = 1, weight = 1 },
			},
		},
		{
			startTimeSeconds = 30,
			maxAlive = 25,
			entryCue = {
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob_2", amount = 25 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
			},
		},
		{
			startTimeSeconds = 60,
			maxAlive = 20,
			entryCue = {
				{ zombieType = "Tank", spawnPointName = "Spawn_Mob", amount = 2 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Tank", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
			},
		},
	}
}

local MountainPass_4: Level = {
	id = "MountainPass_4",
	tiers = {
		{
			startTimeSeconds = 0,
			maxAlive = 10,
			entryCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 10 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_2", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_3", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_4", amount = 1, weight = 1 },
			},
		},
		{
			startTimeSeconds = 30,
			maxAlive = 25,
			entryCue = {
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob_2", amount = 25 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
			},
		},
		{
			startTimeSeconds = 60,
			maxAlive = 20,
			entryCue = {
				{ zombieType = "Tank", spawnPointName = "Spawn_Mob", amount = 2 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Tank", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
			},
		},
	}
}

local MountainPass_5: Level = {
	id = "MountainPass_5",
	tiers = {
		{
			startTimeSeconds = 0,
			maxAlive = 10,
			entryCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 10 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_2", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_3", amount = 1, weight = 1 },
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob_4", amount = 1, weight = 1 },
			},
		},
		{
			startTimeSeconds = 30,
			maxAlive = 25,
			entryCue = {
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob_2", amount = 25 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
			},
		},
		{
			startTimeSeconds = 60,
			maxAlive = 20,
			entryCue = {
				{ zombieType = "Tank", spawnPointName = "Spawn_Mob", amount = 2 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Tank", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
			},
		},
	}
}

return {
	BATTLE_DURATION = 20,
	SCHEDULER_INTERVAL = 0.1,
	ZOMBIE_SPAWN_INTERVAL = 0.2,
	LEVEL_CONTINUE_VOTE_TIMEOUT = 20,
	TIERS = MountainPass_1.tiers,
	LEVEL_ORDER = {
		"MountainPass_1",
		"MountainPass_2",
		"MountainPass_3",
		"MountainPass_4",
		"MountainPass_5",
	},
	LEVELS = {
		MountainPass_1 = MountainPass_1,
		MountainPass_2 = MountainPass_2,
		MountainPass_3 = MountainPass_3,
		MountainPass_4 = MountainPass_4,
		MountainPass_5 = MountainPass_5,
	},
}