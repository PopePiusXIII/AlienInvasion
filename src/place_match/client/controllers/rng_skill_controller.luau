--!strict

local replicated_storage = game:GetService("ReplicatedStorage")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)
local RemoteNames = require(replicated_storage.match.shared.remote_names)
local RngHud = require(replicated_storage.match.ui.rng_hud)

local TAG = "RngSkillController"
local RngSkillController = {}
RngSkillController.Name = TAG

local _rngActivateRemote: RemoteEvent
local _rngPickModifierRemote: RemoteEvent

local function onModifierSelected(key: string)
	_rngPickModifierRemote:FireServer(key)
end

function RngSkillController:Init() end

function RngSkillController:Start()
	_rngActivateRemote = Framework.GetRemote(RemoteNames.RNG_ACTIVATE)
	_rngPickModifierRemote = Framework.GetRemote(RemoteNames.RNG_PICK_MODIFIER)

	Logger.onClientEvent(_rngActivateRemote, TAG, function(options: { string })
		RngHud.show(options, onModifierSelected)
	end)
end

Framework.CreateController(RngSkillController)
return RngSkillController