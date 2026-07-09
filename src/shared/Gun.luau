type GunLevel = "common" | "rare" | "legendary" | "epic" | "mythic"
type GunMerge = {level: GunLevel, base: GunLevel, quantity: number}

local gunMerge: {GunMerge} = {
    {level = "rare",      base = "common",    quantity = 3},
    {level = "legendary", base = "rare",      quantity = 3},
    {level = "epic",      base = "legendary", quantity = 3},
    {level = "mythic",    base = "epic",      quantity = 3},
}

export type GunTracer = {
    lifetime:  number,
    thickness: number,
    color:     Color3,
}

export type Gun = {
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

export type GunCatalog = { [string]: Gun }

return {}