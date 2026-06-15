--!strict
--------------------------------------------------------------------------------
-- RemoteNames.luau  (src/shared → ReplicatedStorage.Shared.RemoteNames)
-- Single source of truth for all RemoteEvent name strings (Match Place).
-- Import this in both Services (server) and Controllers (client) to prevent
-- typo-induced nil-remote bugs that only surface at runtime.
--------------------------------------------------------------------------------

return {
	SHOOT_GUN     = "ShootGun",
	WAVE_ANNOUNCE = "WaveAnnounce",
	WAVE_CLEAR    = "WaveClear",
	RUN_CURRENCY_UPDATED  = "RunCurrencyUpdated",
	REQUEST_SHOP_PURCHASE = "RequestShopPurchase",
	SHOP_PURCHASE_RESULT  = "ShopPurchaseResult",
	LOBBY_ECONOMY_SYNC    = "LobbyEconomySync",
	REQUEST_WEAPON_UNLOCK = "RequestWeaponUnlock",
	WEAPON_UNLOCK_RESULT  = "WeaponUnlockResult",
	OPEN_GUN_SHOP          = "OpenGunShop",
	REQUEST_GUN_PURCHASE   = "RequestGunPurchase",
	GUN_PURCHASE_RESULT    = "GunPurchaseResult",
	REQUEST_FREE_LOADOUT   = "RequestFreeLoadout",
	BOLT_SPAWNED           = "BoltSpawned",
	CLAIM_BOLT             = "ClaimBolt",
	ZOMBIE_HIT_SOUND       = "ZombieHitSound",
}
