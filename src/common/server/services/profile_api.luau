--!strict
-- Server-only namespace for profile-backed domain APIs.

local server_script_service = game:GetService("ServerScriptService")

local services = server_script_service.common.services
local ProfileDb = require(services:WaitForChild("profile_db"))
local GunApi = require(services:WaitForChild("gun_api"))
local EconomyApi = require(services:WaitForChild("economy_api"))

return {
	Db = ProfileDb,
	GunApi = GunApi,
	EconomyApi = EconomyApi,
}