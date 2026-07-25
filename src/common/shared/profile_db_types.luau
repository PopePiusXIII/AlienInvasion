
local ProfileServiceTypes = {}

local replicated_storage = game:GetService("ReplicatedStorage")
local GunCore = require(replicated_storage.shared.gun_core)

export type PlayerProfile = {
	bestWave: number,
	totalGames: number,
	goldStuds: number,
	lifetimeSilverEarned: number,
	lifetimeSilverSpent: number,
	unlockedWeapons: { [string]: boolean },
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
	saveStats: (player: Player, waveReached: number, economy: EconomySummary?) -> (),
	isWeaponUnlocked: (player: Player, weaponName: string) -> boolean,
	tryUnlockWeapon: (player: Player, weaponName: string) -> (boolean, string),
	buyDeveloperGold: (player: Player, dev_product_id: number) -> boolean,

	-- Inventory management
	grantGun: (player: Player, gunName: string) -> string?,
	getInventory: (player: Player) -> { GunCore.GunInstance }?,
	getGun: (player: Player, gunId: string) -> GunCore.GunInstance?,
	removeGun: (player: Player, gunId: string) -> boolean,
	mergeGuns: (player: Player, gunIds: { string }) -> (boolean, string?, string?),
	upgradeLevel: (player: Player, gunId: string) -> (boolean, number?, string?),
	getGunStats: (player: Player, gunId: string, level: number?) -> GunCore.Gun?,
}

return ProfileServiceTypes