--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local RngCore = require(server_script_service.common.modules.rng_core)
local Framework = require(replicated_storage.common.shared.framework)
local Logger    = require(replicated_storage.common.shared.logger)
local RemoteNames = require(replicated_storage.match.shared.remote_names)
local MatchProfileService = require(server_script_service.match.services.skill_service)
local SkillService = require(server_script_service.match.services.skill_service)

local a = SkillService.
local TAG = "RngService"


local RngService = Framework.CreateService({ Name = TAG })

local _rngActivateRemote:     RemoteFunction
local _rngTopupRemote:        RemoteEvent
local _rngRequestGiveRemote:  RemoteEvent

function RngService:Init()
	Logger.info(TAG, "Initialized.")
	    _rngActivateRemote     = Framework.CreateRemoteFunction(RemoteNames.RNG_ACTIVATE)
        _rngTopupRemote        = Framework.CreateRemote(RemoteNames.RNG_TOPUP_AMMO)
        _rngRequestGiveRemote  = Framework.CreateRemote(RemoteNames.RNG_REQUEST_GIVE)
end

function handleRngActivate(player: Player)
	local player_modifiers = MatchProfileService.getModifierTypes(player)
	local modifierNames: { string } = {}
	for modifierName in pairs(player_modifiers) do
		table.insert(modifierNames, modifierName)
	end

	local _random_3 = RngCore.selectRandom3(modifierNames)
	

end

function RngService:Start()
	_rngActivateRemote.OnServerInvoke = handleRngActivate
end

return RngService
