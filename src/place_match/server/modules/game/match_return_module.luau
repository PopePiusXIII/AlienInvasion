--!strict

local MatchReturnModule = {}

function MatchReturnModule.returnAllToLobby(teleportService: TeleportService, lobbyPlaceId: number, playersService: Players, onWarn: (message: string, ...any) -> ())
	local players = playersService:GetPlayers()
	if #players == 0 then return end

	local ok, err = pcall(function()
		teleportService:TeleportAsync(lobbyPlaceId, players)
	end)
	if not ok then
		onWarn("TeleportAsync to lobby failed: %s", tostring(err))
	end
end

return MatchReturnModule
