--!strict

local WaveTypes = {}

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

export type FluxTier = {
	startTimeSeconds: number,
	maxAlive: number,
	entryCue: { CueEntry },
	randomCue: { WeightedCueEntry },
}

export type MatchTimer = {
	expired: boolean,
	stopped: boolean,
}

export type SpawnJob = {
	zombieType: string,
	spawnPointName: string,
}

export type MatchState = {
	participants: { Player },
	participantHumanoids: { [Player]: Humanoid },
	kills: number,
	aliveCount: number,
	activeLevelIndex: number,
	activeTierIndex: number,
	highestTierReached: number,
	nextOwnerIndex: number,
	lastSpawnTime: number,
	queue: { SpawnJob },
	running: boolean,
	voteOpen: boolean,
	eligibleVoters: { [Player]: boolean },
	votesByPlayer: { [Player]: boolean? },
	timer: MatchTimer,
}

return WaveTypes
