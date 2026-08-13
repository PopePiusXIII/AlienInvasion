--!strict
-- Studio-only profile preset selection and in-place application.

local replicated_storage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DevProfileConfig = require(replicated_storage.common.shared.configs:WaitForChild("dev_profile_config"))
local ProfileDbType = require(replicated_storage.common.shared.profile_db_types)

type PlayerProfile = ProfileDbType.PlayerProfile

local ProfileDbDev = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, nestedValue in value do
		copy[deepCopy(key)] = deepCopy(nestedValue)
	end
	return copy
end

local function clearTable(target: { [any]: any })
	for key in target do
		target[key] = nil
	end
end

local function getActiveProfile(expectedSchemaVersion: number): PlayerProfile
	local activeProfile = DevProfileConfig.PROFILES[DevProfileConfig.ACTIVE_PROFILE]
	if not activeProfile then
		error(string.format("DevProfileConfig ACTIVE_PROFILE %q does not exist.", DevProfileConfig.ACTIVE_PROFILE))
	end
	if activeProfile.schemaVersion ~= expectedSchemaVersion then
		error(string.format(
			"DevProfileConfig profile %q has schema version %d; expected %d.",
			DevProfileConfig.ACTIVE_PROFILE,
			activeProfile.schemaVersion,
			expectedSchemaVersion
		))
	end
	return activeProfile
end

function ProfileDbDev.isEnabled(): boolean
	return RunService:IsStudio() and DevProfileConfig.USE_SPOOF
end

function ProfileDbDev.getStoreName(productionStoreName: string): string
	if ProfileDbDev.isEnabled() then
		return productionStoreName .. "_Studio"
	end
	return productionStoreName
end

function ProfileDbDev.applyActiveProfile(profile: PlayerProfile, expectedSchemaVersion: number): string
	local activeProfile = getActiveProfile(expectedSchemaVersion)
	clearTable(profile)
	for key, value in activeProfile do
		profile[key] = deepCopy(value)
	end
	return DevProfileConfig.ACTIVE_PROFILE
end

return ProfileDbDev