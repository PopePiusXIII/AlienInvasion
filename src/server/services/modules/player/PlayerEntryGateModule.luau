--!strict

local PlayerEntryGateModule = {}

function PlayerEntryGateModule.isEligibleToPlay(activePlayers: { [Player]: boolean }, player: Player): boolean
	if activePlayers[player] then return false end
	local character = player.Character
	local humanoid  = character and character:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
	return humanoid ~= nil and (humanoid :: Humanoid).Health > 0
end

return PlayerEntryGateModule
