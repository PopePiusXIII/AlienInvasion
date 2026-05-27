--!strict
--------------------------------------------------------------------------------
-- CombatService.luau  (src/server/services)
-- Owns the ShootGun RemoteEvent.
-- Receives hit reports from the client and applies server-authoritative damage.
-- Single Responsibility: server-side hit validation and damage routing.
--
-- Security notes:
--   • The client sends the Instance it thinks it hit. Server re-validates:
--     name == "Zombie", parent == workspace, has a live Humanoid.
--   • ZombieService.damageZombie() is the authoritative damage gate.
--   • Logger.wrapServerEvent() pcall-isolates this handler from the server thread.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework     = require(ReplicatedStorage.Shared.Framework)
local Logger        = require(ReplicatedStorage.Shared.Logger)
local Config        = require(ReplicatedStorage.Shared.Config)
local RemoteNames   = require(ReplicatedStorage.Shared.RemoteNames)
local ZombieService = require(script.Parent.ZombieService)

local TAG = "CombatService"

local CombatService = Framework.CreateService({ Name = TAG })

local function resolveDamage(gunName: string?): number
	local statsByName = Config.GUN_STATS :: { [string]: any }
	if gunName and statsByName[gunName] and type(statsByName[gunName].damage) == "number" then
		return statsByName[gunName].damage
	end
	return Config.GUN_DAMAGE
end

function CombatService:Init()
	local shootRemote = Framework.CreateRemote(RemoteNames.SHOOT_GUN)

	-- Logger.wrapServerEvent provides:
	--   1. Automatic pcall — a buggy payload never crashes the server thread.
	--   2. Net trace      — args logged when Config.DEBUG_NETWORKING = true.
	Logger.wrapServerEvent(shootRemote, TAG, function(_player: Player, zombieModel: Instance, gunName: string?)
		ZombieService.damageZombie(zombieModel :: Model?, resolveDamage(gunName))
	end)

	Logger.info(TAG, "ShootGun handler registered.")
end

return CombatService
