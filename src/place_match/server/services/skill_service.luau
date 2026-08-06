--!strict
--------------------------------------------------------------------------------
-- SkillService.luau  (src/server/services)
-- Manages cumulative modifier state for in-match stat boosts.
-- When a player picks an RNG modifier, it compounds multiplicatively into
-- their modifier profile.
--
-- Public API:
--   SkillService.getGunModifiers(player)    → GunModifier table
--   SkillService.getPlayerModifiers(player) → PlayerModifier table
--   SkillService.apply(player, key)         → apply a modifier pick
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ── Type imports (compile-time only) ────────────────────────────────────────
local SkillProfile = require(replicated_storage.match.shared.types.skill_types)
local Framework      = require(replicated_storage.common.shared.framework)
local Logger         = require(replicated_storage.common.shared.logger)
local ModifierConfig = require(replicated_storage.match.shared.configs.match_profile_config)
local ModifierCategory = require(replicated_storage.match.shared.modifier_category)

local TAG = "SkillService"
local SkillService = {}
SkillService.Name = TAG
-- ── State ────────────────────────────────────────────────────────────────────

local _playerModifiers: { [Player]: SkillProfile.SkillProfile } = {}
local _healthModifierChanged = Instance.new("BindableEvent")


local function buildEmptyModifierProfile(): SkillProfile.SkillProfile
	local gun_modifier: SkillProfile.GunModifier = {
		reload_speed = 1.0,
		ammo_capacity = 1.0,
		damage = 1.0,
		fire_rate = 1.0,
		bullet_penetration = false,
		knockback = 1.0,
	}
	for _, entry in pairs(ModifierConfig) do
		if entry.category == ModifierCategory.gun then
			gun_modifier[entry.property] = 1.0
		end
	end

	local player_modifier: SkillProfile.PlayerModifier = {
		health = 1.0,
		speed = 1.0,
	}
	for _, entry in pairs(ModifierConfig) do
		if entry.category == ModifierCategory.player then
			player_modifier[entry.property] = 1.0
		end
	end

	return { gun_modifier = gun_modifier, player_modifier = player_modifier }
end

local function ensureModifiers(player: Player)
	if _playerModifiers[player] then return end
	_playerModifiers[player] = buildEmptyModifierProfile()
	Logger.info(TAG, "Initialized modifier profile for %s.", player.Name)
end

-- ── Public API ───────────────────────────────────────────────────────────────

--- Returns the cumulative gun modifier table for a player.
function SkillService.getGunModifiers(player: Player): SkillProfile.GunModifier
	ensureModifiers(player)
	return _playerModifiers[player].gun_modifier :: SkillProfile.GunModifier
end

--- Returns the cumulative player modifier table for a player.
function SkillService.getPlayerModifiers(player: Player): SkillProfile.PlayerModifier
	ensureModifiers(player)
	return _playerModifiers[player].player_modifier :: SkillProfile.PlayerModifier
end

function SkillService.onHealthModifierChanged(
	callback: (Player, number) -> ()
): RBXScriptConnection
	return _healthModifierChanged.Event:Connect(callback)
end

--- Apply a modifier pick to a player's profile.
--- The key should match a key in ModifierConfig (e.g. "gun_damage", "player_health").
function SkillService.apply(player: Player, key: string)
	local entry = ModifierConfig[key]
	if not entry then
		Logger.warn(TAG, "Unknown modifier key '%s' from %s.", key, player.Name)
		return
	end

	ensureModifiers(player)
	local profile = _playerModifiers[player]

	if entry.category == ModifierCategory.gun then
		local gunMod = profile.gun_modifier :: SkillProfile.GunModifier
		gunMod[entry.property] = (gunMod[entry.property] or 1.0) * entry.value
		Logger.info(TAG, "%s applied %s → gun.%s = %.2f", player.Name, key, entry.property, gunMod[entry.property])
	elseif entry.category == ModifierCategory.player then
		local playerMod = profile.player_modifier :: SkillProfile.PlayerModifier
		playerMod[entry.property] = (playerMod[entry.property] or 1.0) * entry.value
		Logger.info(TAG, "%s applied %s → player.%s = %.2f", player.Name, key, entry.property, playerMod[entry.property])
		if entry.property == "health" then
			_healthModifierChanged:Fire(player, playerMod.health)
		end
	end
end

function SkillService.getModifierTypes(player: Player): SkillProfile.ModifierOptions
	ensureModifiers(player)
	local modifiers: SkillProfile.ModifierOptions = {}
	for key in pairs(ModifierConfig) do
		table.insert(modifiers, key)
	end
	return modifiers
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────

function SkillService:Init()
	Logger.info(TAG, "Initialized.")
end

function SkillService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		_playerModifiers[player] = nil
	end)
	Logger.info(TAG, "Listeners connected.")
end

SkillService = Framework.CreateService(SkillService)

return SkillService
