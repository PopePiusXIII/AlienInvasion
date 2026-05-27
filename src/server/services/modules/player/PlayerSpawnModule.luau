--!strict

local PlayerSpawnModule = {}

function PlayerSpawnModule.spawnAtLobby(character: Model, lobbyName: string)
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if not hrp then return end

	task.wait()
	local lobby = workspace:FindFirstChild(lobbyName)
	if not lobby or not lobby:IsA("Model") then return end

	local spawnPart = lobby:FindFirstChild("Spawn_In", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		character:PivotTo((spawnPart :: BasePart).CFrame * CFrame.new(0, 5, 0))
	else
		character:PivotTo((lobby :: Model):GetPivot() * CFrame.new(0, 5, 0))
	end
end

return PlayerSpawnModule
