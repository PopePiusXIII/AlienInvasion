--!strict

local replicated_storage = game:GetService("ReplicatedStorage")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)
local RngHud = require(replicated_storage.match.ui.rng_hud)
local MatchHUD = require(replicated_storage.match.ui.match_hud)
local SkillTypes = require(replicated_storage.match.shared.types.skill_types)

local TAG = "RngSkillController"
local RngSkillController = {}
RngSkillController.Name = TAG

local _rngActivateRemote: RemoteEvent
local _rngPickModifierRemote: RemoteEvent
local _skillsSyncRemote: RemoteEvent

local function onModifierSelected(key: string)
	_rngPickModifierRemote:FireServer(key)
end

local function onRngActivated(options: { string })
	RngHud.show(options, onModifierSelected)
end

local function onSkillsSynced(skills: SkillTypes.OwnedSkills)
	MatchHUD.sources.skills(skills)
end

function RngSkillController:Init() end

function RngSkillController:Start()
	_rngActivateRemote = Framework.GetRemote("RngActivated")
	_rngPickModifierRemote = Framework.GetRemote("SelectRngModifier")
	_skillsSyncRemote = Framework.GetRemote("SkillsUpdated")

	Logger.onClientEvent(_rngActivateRemote, TAG, onRngActivated)
	Logger.onClientEvent(_skillsSyncRemote, TAG, onSkillsSynced)
end

Framework.CreateController(RngSkillController)
return RngSkillController