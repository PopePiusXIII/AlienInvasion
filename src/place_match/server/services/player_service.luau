--!strict
--------------------------------------------------------------------------------
-- PlayerService.luau  (src/server/services)
-- Manages player lifecycle events for the Match Place.
-- Battle start is driven entirely by GameService.startMatch().
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)

local TAG = "PlayerService"

local PlayerService = Framework.CreateService({ Name = TAG })

-- ── Lifecycle ─────────────────────────────────────────────────────

function PlayerService:Init()
	Logger.info(TAG, "Initialized.")
end

function PlayerService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		Logger.info(TAG, "%s left the match.", player.Name)
	end)

	Logger.info(TAG, "Player lifecycle listeners connected.")
end

return PlayerService
