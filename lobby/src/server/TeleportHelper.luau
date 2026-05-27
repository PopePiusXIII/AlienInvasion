--!strict
-- TeleportHelper.luau  (Lobby Place — ServerScriptService)
-- Wraps TeleportService calls with retry logic and pcall protection.

local TeleportService   = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TeleportHelper = {}

local MAX_RETRIES  = 3
local RETRY_DELAY  = 2

local function withRetry(label: string, fn: () -> ()): boolean
	for attempt = 1, MAX_RETRIES do
		local ok, err = pcall(fn)
		if ok then return true end
		warn(string.format("[TeleportHelper] %s attempt %d/%d failed: %s",
			label, attempt, MAX_RETRIES, tostring(err)))
		if attempt < MAX_RETRIES then task.wait(RETRY_DELAY) end
	end
	return false
end

-- Reserves a fresh match server and teleports the given players to it.
-- Returns true on success.
function TeleportHelper.teleportToMatch(players: { Player }): boolean
	if #players == 0 then return false end

	local accessCode: string? = nil
	local reserved = withRetry("ReserveServer", function()
		accessCode = TeleportService:ReserveServer(Config.MATCH_PLACE_ID)
	end)
	if not reserved or not accessCode then
		warn("[TeleportHelper] Could not reserve a match server.")
		return false
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode :: string
	options.ShouldReserveServer      = false

	return withRetry("TeleportAsync to match", function()
		TeleportService:TeleportAsync(Config.MATCH_PLACE_ID, players, options)
	end)
end

-- Sends a group of players back to the Lobby place.
function TeleportHelper.returnToLobby(players: { Player })
	if #players == 0 then return end
	withRetry("TeleportAsync to lobby", function()
		TeleportService:TeleportAsync(Config.LOBBY_PLACE_ID, players)
	end)
end

return TeleportHelper
