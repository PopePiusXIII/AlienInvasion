--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RngCore = require(ServerScriptService.ServerModules.RngCore)
local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local MatchProfileService = require(script.Parent.MatchProfileService)
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