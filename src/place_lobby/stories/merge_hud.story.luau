--!strict

local mergeModule = game.ReplicatedStorage.common.shared.vide.merge :: ModuleScript
local Merge = require(mergeModule) :: () -> ScreenGui

local function story(target: Instance)
	local mergeGui = Merge()
	local mergeFrame = mergeGui:FindFirstChild("Parent_Frame")
	if not mergeFrame or not mergeFrame:IsA("Frame") then
		mergeGui:Destroy()
		error("Merge UI is missing Parent_Frame")
	end

	mergeFrame.Parent = target

	local function cleanup()
		mergeFrame:Destroy()
		mergeGui:Destroy()
	end

	return cleanup
end

return story