
local ProfileServiceTypes = {}

local replicated_storage = game:GetService("ReplicatedStorage")
local GunCore = require(replicated_storage.common.shared.gun_core)

export type WeaponUnlocks = { [string]: { [GunCore.GunRarity]: boolean } }

export type PlayerProfile = {
	schemaVersion: number,
	bestWave: number,
	totalGames: number,
	goldStuds: number,
	lifetimeSilverEarned: number,
	lifetimeSilverSpent: number,
	unlockedWeapons: WeaponUnlocks,
	inventory: { [string]: GunCore.GunInstance },  -- keyed by UUID
}

export type EconomySummary = {
	silverEarned: number,
	silverSpent: number,
	goldEarned: number,
}

export type API = {
	-- Session access (defined with :, so self is first arg)
	GetSession: (self: any, player: Player) -> any?,
	GetProfile: (self: any, player: Player) -> PlayerProfile?,
	WaitForProfile: (self: any, player: Player) -> PlayerProfile?,

	-- Callbacks
	OnProfileLoaded: (callback: (player: Player, profile: PlayerProfile) -> ()) -> (),
	OnProfileChanged: (callback: (player: Player, profile: PlayerProfile) -> ()) -> (),

	-- Data operations
	save: (player: Player) -> (),
	NotifyChanged: (player: Player, profile: PlayerProfile) -> (),
}

export type EconomyAPI = {
	saveStats: (player: Player, waveReached: number, economy: EconomySummary?) -> (),
	isWeaponUnlocked: (player: Player, weaponName: string, rarity: GunCore.GunRarity) -> boolean,
	tryUnlockWeapon: (player: Player, weaponName: string, rarity: GunCore.GunRarity) -> (boolean, string),
	buyDeveloperGold: (player: Player, devProductId: number) -> boolean,
}

export type GunAPI = {
	grantGun: (player: Player, gunName: string, rarity: GunCore.GunRarity) -> string?,
	getInventory: (player: Player) -> { GunCore.GunInstance }?,
	getGun: (player: Player, gunId: string) -> GunCore.GunInstance?,
	removeGun: (player: Player, gunId: string) -> boolean,
	mergeGuns: (player: Player, gunIds: { string }) -> (boolean, string?, string?),
	upgradeLevel: (player: Player, gunId: string) -> (boolean, number?, string?),
	getGunStats: (player: Player, gunId: string, level: number?) -> GunCore.Gun?,
}

return ProfileServiceTypes
