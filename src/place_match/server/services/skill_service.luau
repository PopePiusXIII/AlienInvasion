--!strict
--------------------------------------------------------------------------------
-- MatchProfileService.luau  (src/server/services)
-- Manages cumulative modifier state for in-match stat boosts.
-- When a player picks an RNG modifier, it compounds multiplicatively into
-- their modifier profile.
--
-- Public API:
--   MatchProfileService.getGunModifiers(player)    → GunModifier table
--   MatchProfileService.getPlayerModifiers(player) → PlayerModifier table
--   MatchProfileService.apply(player, key)         → apply a modifier pick
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")

-- ── Type imports (compile-time only) ────────────────────────────────────────
local MatchProfile = require(replicated_storage.match.shared.types.match_profile)
local MatchProfileServiceTypes = require(replicated_storage.match.shared.types.match_profile_service_types)
local Framework      = require(replicated_storage.common.shared.framework)
local Logger         = require(replicated_storage.common.shared.logger)
local RemoteNames    = require(replicated_storage.match.shared.remote_names)
local ModifierConfig = require(replicated_storage.match.shared.configs.match_profile_config)

local TAG = "MatchProfileService"

local MatchProfileService = Framework.CreateService({ Name = TAG }) :: MatchProfileServiceTypes.API

-- ── State ────────────────────────────────────────────────────────────────────

local _playerModifiers: { [Player]: MatchProfile.MatchProfile } = {}

---------------------------------- Helper Functions -------------------------------------

local function buildEmptyModifierProfile(): MatchProfile.MatchProfile
	local gun_modifier: MatchProfile.GunModifer = {
		reload_speed = 1.0,
		ammo_capacity = 1.0,
		damage = 1.0,
		fire_rate = 1.0,
	}
	for _, entry in pairs(ModifierConfig) do
		if entry.category == "gun" then
			gun_modifier[entry.property] = 1.0
		end
	end

	local player_modifier: MatchProfile.PlayerModifier = {
		health = 1.0,
		speed = 1.0,
	}
	for _, entry in pairs(ModifierConfig) do
		if entry.category == "player" then
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
function MatchProfileService.getGunModifiers(player: Player): MatchProfile.GunModifer
	ensureModifiers(player)
	return _playerModifiers[player].gun_modifier :: MatchProfile.GunModifer
end

--- Returns the cumulative player modifier table for a player.
function MatchProfileService.getPlayerModifiers(player: Player): MatchProfile.PlayerModifier
	ensureModifiers(player)
	return _playerModifiers[player].player_modifier :: MatchProfile.PlayerModifier
end

--- Apply a modifier pick to a player's profile.
--- The key should match a key in ModifierConfig (e.g. "gun_damage", "player_health").
function MatchProfileService.apply(player: Player, key: string)
	local entry = ModifierConfig[key]
	if not entry then
		Logger.warn(TAG, "Unknown modifier key '%s' from %s.", key, player.Name)
		return
	end

	ensureModifiers(player)
	local profile = _playerModifiers[player]

	if entry.category == "gun" then
		local gunMod = profile.gun_modifier :: MatchProfile.GunModifer
		gunMod[entry.property] = (gunMod[entry.property] or 1.0) * entry.value
		Logger.info(TAG, "%s applied %s → gun.%s = %.2f", player.Name, key, entry.property, gunMod[entry.property])
	elseif entry.category == "player" then
		local playerMod = profile.player_modifier :: MatchProfile.PlayerModifier
		playerMod[entry.property] = (playerMod[entry.property] or 1.0) * entry.value
		Logger.info(TAG, "%s applied %s → player.%s = %.2f", player.Name, key, entry.property, playerMod[entry.property])
	end
end

function MatchProfileService.getModifierTypes(player: Player): MatchProfile.FlatModifiers
	ensureModifiers(player)
	return MatchProfile.into(_playerModifiers[player])
end

-- ── Remote Handlers ──────────────────────────────────────────────────────────

local _rngPickModifierRemote: RemoteEvent? = nil

-- ── Lifecycle ────────────────────────────────────────────────────────────────

function MatchProfileService:Init()
	_rngPickModifierRemote = Framework.CreateRemote(RemoteNames.RNG_PICK_MODIFIER)
	Logger.info(TAG, "Initialized.")
end

function MatchProfileService:Start()
	if _rngPickModifierRemote then
		_rngPickModifierRemote.OnServerEvent:Connect(MatchProfileService.apply)
	end
	Logger.info(TAG, "Listeners connected.")
end

return MatchProfileService
