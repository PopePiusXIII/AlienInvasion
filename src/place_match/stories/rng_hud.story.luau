--!strict

local Inventory = require(game.replicated_storage.shared.ui.RngHud)

local function story(target: Instance)
	Inventory.Parent = target
	Inventory.Enabled = true

	local closeButton = Inventory:FindFirstChild("X_Button", true)
	if closeButton and closeButton:IsA("ImageButton") then
		closeButton.Activated:Connect(function()
			Inventory.Enabled = false
		end)
	end

	return function()
		Inventory:Destroy()
	end
end

return story
