--!strict
-- Ordered, persisted PlayerProfile schema migrations.

local replicated_storage = game:GetService("ReplicatedStorage")

local CombatConfig = require(replicated_storage.common.shared.configs.combat_config)
local GunCore = require(replicated_storage.common.shared.gun_core)
local ProfileDbType = require(replicated_storage.common.shared.profile_db_types)

type PlayerProfile = ProfileDbType.PlayerProfile

local ProfileDbMigrations = {
	CURRENT_SCHEMA_VERSION = 1,
}

local function migrateVersionZero(profile: PlayerProfile)
	for _, weapon in ipairs(CombatConfig.STARTER_UNLOCKED_WEAPONS) do
		profile.unlockedWeapons[weapon.name] = {
			[weapon.rarity :: GunCore.GunRarity] = true,
		}
	end
	profile.schemaVersion = ProfileDbMigrations.CURRENT_SCHEMA_VERSION
end

function ProfileDbMigrations.apply(profile: PlayerProfile)
	if profile.schemaVersion == 0 then
		migrateVersionZero(profile)
	end
	if profile.schemaVersion == ProfileDbMigrations.CURRENT_SCHEMA_VERSION then
		return
	end
	if profile.schemaVersion ~= ProfileDbMigrations.CURRENT_SCHEMA_VERSION then
		error(string.format(
			"Unsupported profile schema version %s; expected 0 or %d.",
			tostring(profile.schemaVersion),
			ProfileDbMigrations.CURRENT_SCHEMA_VERSION
		))
	end
end

return ProfileDbMigrations