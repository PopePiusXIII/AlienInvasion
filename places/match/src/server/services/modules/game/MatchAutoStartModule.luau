--!strict

local MatchAutoStartModule = {}

function MatchAutoStartModule.waitForMatchStart(playersService: Players, requiredPlayers: number, timeoutSeconds: number): boolean
	local deadline = os.clock() + timeoutSeconds
	while os.clock() < deadline do
		if #playersService:GetPlayers() >= requiredPlayers then
			return true
		end
		task.wait(1)
	end

	return #playersService:GetPlayers() > 0
end

return MatchAutoStartModule
