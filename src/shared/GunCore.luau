export type GunRarity = "common" | "rare" | "legendary" | "epic" | "mythic"
export type GunLevel = number
export type GunTracer = {
    lifetime:  number,
    thickness: number,
    color:     Color3,
}

export type GunInstance = {
    id: string,           -- UUID per instance (auto-increment counter)
    name: string,         -- "1911", "Deagle" (key into GUN_STATS base name)
    rarity: GunRarity,
}

--- Base gun stats for a specific rarity tier (no level applied).
--- Lives in GUN_STATS as the source of truth per rarity.
export type Gun = {
    rarity:         GunRarity,
    damage:         number,
    gold_cost:      number?,
    image:          string?,
    range:          number,
    fireCooldown:   number,
    magSize:        number,
    max_ammo:       number,
    reloadTime:     number,
    isAutomatic:    boolean,
    isShotgun:      boolean?,
    knockbackForce: number,
    tracer:         GunTracer,
}

--- Per-level multiplier applied on top of a Gun's base rarity stats.
export type GunLevelModifier = {
    damage:     number,   -- multiply
    knockback:  number,   -- multiply
    range:      number,   -- multiply
    magSize:    number,   -- multiply
    cooldownDiv: number,  -- divide fireCooldown by this
}

export type GunCatalog = { [string]: Gun }

return {}
