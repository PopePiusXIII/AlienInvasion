--!strict

export type CueEntry = {
	zombieType: string,
	spawnPointName: string,
	amount: number,
}

export type WeightedCueEntry = CueEntry & {
	weight: number,
}

export type Tier = {
	startTimeSeconds: number,
	maxAlive: number,
	entryCue: { CueEntry },
	randomCue: { WeightedCueEntry },
}

return {
	BATTLE_DURATION = 300,
	SCHEDULER_INTERVAL = 0.1,
	SPAWN_INTERVAL = 0.2,
	TIERS = {
		{
			startTimeSeconds = 0,
			maxAlive = 10,
			entryCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 10 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
			},
		},
		{
			startTimeSeconds = 120,
			maxAlive = 15,
			entryCue = {
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob", amount = 3 },
			},
			randomCue = {
				{ zombieType = "Normal", spawnPointName = "Spawn_Mob", amount = 1, weight = 2 },
				{ zombieType = "Normal_Run", spawnPointName = "Spawn_Mob", amount = 1, weight = 1 },
			},
		},
		{
			startTimeSeconds = 240,
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
	},
}