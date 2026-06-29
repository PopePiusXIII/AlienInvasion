--!strict
--------------------------------------------------------------------------------
-- MatchmakingController.luau  (places/lobby/src/client/controllers)
-- Owns all lobby matchmaking queue state: join, cancel, match found countdown.
-- Fires JoinQueue / LeaveQueue via Logger.fireServer.
-- Listens to MatchFound.
-- Single Responsibility: queue logic and client-side state only.
-- All UI is delegated to LobbyHudController (reactive vide components).
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Framework   = require(ReplicatedStorage.Shared.Framework)
local Logger      = require(ReplicatedStorage.Shared.Logger)
local Config      = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local LobbyHudController = require(script.Parent.LobbyHudController)

local TAG = "MatchmakingController"

local MatchmakingController = Framework.CreateController({ Name = TAG })

local _localPlayer     = Players.LocalPlayer
local _joinQueueRemote:  RemoteEvent
local _leaveQueueRemote: RemoteEvent
local _matchFoundRemote: RemoteEvent

-- Client-side queue state.
local _isQueued    = false
local _matchLocked = false  -- true once a match is found; prevents further input

-- ── Private state helpers ─────────────────────────────────────────────────────

local function setQueued(queued: boolean)
	_isQueued = queued
	if queued then
		LobbyHudController.setButtonText("CANCEL", true)
		LobbyHudController.setStatus("Searching for players...")
	else
		LobbyHudController.setButtonText("FIND MATCH", true)
		LobbyHudController.setStatus("Click FIND MATCH to enter the queue.")
	end
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function MatchmakingController:Init()
	Logger.info(TAG, "Initialized.")
end

function MatchmakingController:Start()
	_joinQueueRemote  = Framework.GetRemote(RemoteNames.JOIN_QUEUE)
	_leaveQueueRemote = Framework.GetRemote(RemoteNames.LEAVE_QUEUE)
	_matchFoundRemote = Framework.GetRemote(RemoteNames.MATCH_FOUND)

	-- Register the button click handler with LobbyHudController.
	LobbyHudController.setFindMatchCallback(function()
		if _matchLocked then return end
		if _isQueued then
			Logger.fireServer(_leaveQueueRemote)
			setQueued(false)
		else
			Logger.fireServer(_joinQueueRemote)
			setQueued(true)
		end
	end)

	Logger.wrapClientEvent(_matchFoundRemote, TAG, function()
		_matchLocked = true
		LobbyHudController.setButtonText("", false)  -- disable button

		-- 3-second countdown, then "Teleporting…" — mirrors the server's task.delay(3).
		for i = 3, 1, -1 do
			LobbyHudController.setStatus(string.format("Match found!  Starting in  %d…", i))
			task.wait(1)
		end
		LobbyHudController.setStatus("Teleporting…")
	end)

	-- Proximity gate: create the panel only when the player is near the GoToGame pad.
	task.spawn(function()
		local pad: BasePart? = nil
		while not pad do
			local found = workspace:FindFirstChild(Config.LOBBY_PAD_NAME, true)
			if found and found:IsA("BasePart") then
				pad = found :: BasePart
			else
				task.wait(1)
			end
		end
		local PAD_THRESHOLD = 12
		RunService.Heartbeat:Connect(function()
			if _matchLocked then return end  -- keep visible during the countdown
			local char = _localPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				LobbyHudController.setPanelVisible(false)
				return
			end
			local inRange = (root.Position - (pad :: BasePart).Position).Magnitude <= PAD_THRESHOLD
			if inRange then
				LobbyHudController.setPanelVisible(true)
			elseif not _isQueued then
				-- Not near pad and not queued → hide and destroy.
				LobbyHudController.hidePanel()
			end
		end)
	end)

	Logger.info(TAG, "Queue remotes acquired; button and MatchFound listener active.")
end

return MatchmakingController
