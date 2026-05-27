--!strict
--------------------------------------------------------------------------------
-- TeleportHelperService.luau  (lobby/src/server/services)
-- Wraps TeleportService calls with retry logic and pcall protection.
-- Single Responsibility: teleportation only — no queue management, no UI.
--
-- Public API:
--   TeleportHelperService.teleportToMatch(players)  → boolean (success)
--   TeleportHelperService.returnToLobby(players)
--------------------------------------------------------------------------------

local TeleportService   = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)

local TAG = "TeleportHelperService"

local TeleportHelperService = Framework.CreateService({ Name = TAG })

local MAX_RETRIES = 3
local RETRY_DELAY = 2

function TeleportHelperService:Init()
	Logger.info(TAG, "Initialized.")
end

-- ── Private helpers ───────────────────────────────────────────────────────────

local function withRetry(label: string, fn: () -> ()): boolean
	for attempt = 1, MAX_RETRIES do
		local ok, err = pcall(fn)
		if ok then return true end
		Logger.warn(TAG, "%s attempt %d/%d failed: %s", label, attempt, MAX_RETRIES, tostring(err))
		if attempt < MAX_RETRIES then task.wait(RETRY_DELAY) end
	end
	return false
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Reserve a fresh match server and teleport [players] to it.
--- Returns true on success.
function TeleportHelperService.teleportToMatch(players: { Player }): boolean
	if #players == 0 then return false end

	local accessCode: string? = nil
	local reserved = withRetry("ReserveServer", function()
		accessCode = TeleportService:ReserveServer(Config.MATCH_PLACE_ID)
	end)
	if not reserved or not accessCode then
		Logger.warn(TAG, "Could not reserve a match server.")
		return false
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode :: string
	options.ShouldReserveServer      = false

	return withRetry("TeleportAsync→match", function()
		TeleportService:TeleportAsync(Config.MATCH_PLACE_ID, players, options)
	end)
end

--- Teleport [players] back to the Lobby place.
function TeleportHelperService.returnToLobby(players: { Player })
	if #players == 0 then return end
	withRetry("TeleportAsync→lobby", function()
		TeleportService:TeleportAsync(Config.LOBBY_PLACE_ID, players)
	end)
end

return TeleportHelperService
