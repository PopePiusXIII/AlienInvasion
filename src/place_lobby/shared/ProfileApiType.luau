--!strict

local ProfileApiType = {}

export type OwnedItem = {
	id: string,
	name: string,
	rarity: string,
}

export type ProfileSnapshot = {
	gold: number,
	silver: number,
	unlockedWeapons: { string },
	inventory: { OwnedItem },
}

export type ProfileChangedCallback = (profile: ProfileSnapshot) -> ()

export type API = {
	start: () -> (),
	getProfile: () -> ProfileSnapshot,
	onChanged: (callback: ProfileChangedCallback) -> (() -> ()),
	purchaseWeapon: (weaponName: string) -> (),
}

return ProfileApiType
