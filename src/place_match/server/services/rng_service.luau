--!strict
local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local SkillService = require(server_script_service.match.services.skill_service)
local RngCore = require(server_script_service.common.modules.rng_core)
local Framework = require(replicated_storage.common.shared.framework)
local Logger    = require(replicated_storage.common.shared.logger)
local SkillTypes = require(replicated_storage.match.shared.types.skill_types)

local TAG = "RngService"
local RngService = {}
RngService.Name = TAG


local _rngActivateRemote:     RemoteEvent
local _rngRequestGiveRemote:  RemoteEvent
local _rngPickModifierRemote: RemoteEvent
local _pendingOptions: { [Player]: { string } } = {}

function RngService:Init()
	Logger.info(TAG, "Initialized.")
	_rngActivateRemote = Framework.CreateRemote("RngActivated")
	_rngRequestGiveRemote = Framework.CreateRemote("RequestRngReward")
	_rngPickModifierRemote = Framework.CreateRemote("SelectRngModifier")
end

function RngService.activate(player: Player): SkillTypes.ModifierOptions
	local modifierOptions = RngCore.selectRandom3(SkillService.getModifierTypes(player))
	_pendingOptions[player] = modifierOptions
	_rngActivateRemote:FireClient(player, modifierOptions)
	return modifierOptions
end

local function onModifierPicked(player: Player, key: string)
	local options = _pendingOptions[player]
	if not options or not table.find(options, key) then
		Logger.warn(TAG, "Rejected invalid modifier pick '%s' from %s.", key, player.Name)
		return
	end

	_pendingOptions[player] = nil
	SkillService.apply(player, key)
end

function RngService:Start()
	Logger.onServerEvent(_rngPickModifierRemote, TAG, onModifierPicked)
end

Framework.CreateService(RngService)
return RngService
