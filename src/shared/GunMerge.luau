local Gun = require(script.Parent.GunCore)

type MergeRule = { toRarity: Gun.GunRarity, fromRarity: Gun.GunRarity, quantity: number }

local mergeRules: { MergeRule } = {
    { toRarity = "rare",      fromRarity = "common",    quantity = 3 },
    { toRarity = "legendary", fromRarity = "rare",      quantity = 3 },
    { toRarity = "epic",      fromRarity = "legendary", quantity = 3 },
    { toRarity = "mythic",    fromRarity = "epic",      quantity = 3 },
}

--- Merge multiple same-rarity gun instances into one at the next rarity tier.
--- Returns the upgraded rarity, or the original rarity if no upgrade is possible.
function merge_guns(guns: { Gun.GunInstance }): Gun.GunRarity
    if #guns == 0 then error("No guns to merge") end

    local baseRarity = guns[1].rarity
    for _, g in ipairs(guns) do
        if g.rarity ~= baseRarity then error("All guns must be the same rarity") end
    end

    for _, rule in ipairs(mergeRules) do
        if rule.fromRarity == baseRarity and #guns >= rule.quantity then
            return rule.toRarity
        end
    end

    return baseRarity -- Cannot upgrade further (already mythic or not enough guns)
end

return merge_guns