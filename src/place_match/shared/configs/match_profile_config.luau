--!strict
local ModifierCategory = require(script.Parent.Parent.modifier_category)

local PLAYER_MODIFIERS = {
	player_health = { category = ModifierCategory.player, property = "health", value = 1.1, name = "Health", image = "rbxassetid://121484103038270" },
	player_speed = { category = ModifierCategory.player, property = "speed", value = 1.1, name = "Speed", image = "rbxassetid://121484103038270" },
	gun_damage = { category = ModifierCategory.gun, property = "damage", value = 1.1, name = "Damage", image = "rbxassetid://121484103038270" },
	gun_reload_speed = { category = ModifierCategory.gun, property = "reload_speed", value = 1.1, name = "Reload Speed", image = "rbxassetid://121484103038270" },
	gun_fire_rate = { category = ModifierCategory.gun, property = "fire_rate", value = 1.1, name = "Fire Rate", image = "rbxassetid://121484103038270" },
	gun_ammo_capacity = { category = ModifierCategory.gun, property = "ammo_capacity", value = 1.1, name = "Ammo Capacity", image = "rbxassetid://121484103038270" },
}

return PLAYER_MODIFIERS