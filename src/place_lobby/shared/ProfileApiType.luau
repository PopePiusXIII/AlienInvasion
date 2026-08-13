--!strict

local ProfileApiType = {}

export type OwnedItem = {
	id: string,
	name: string,
	rarity: string,
}

export type UnlockedWeapon = {
	name: string,
	rarity: string,
}

export type ProfileSnapshot = {
	gold: number,
	silver: number,
	unlockedWeapons: { UnlockedWeapon },
	inventory: { OwnedItem },
}

export type ProfileChangedCallback = (profile: ProfileSnapshot) -> ()

export type API = {
	start: () -> (),
	getProfile: () -> ProfileSnapshot,
	onChanged: (callback: ProfileChangedCallback) -> (() -> ()),
	purchaseWeapon: (weaponName: string, rarity: string) -> (),
}

return ProfileApiType
