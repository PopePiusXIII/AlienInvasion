--!strict

local LobbyMainHUD = require(game.ReplicatedStorage.Shared.vide.LobbyMainHUD)
local MatchmakingHUD = require(game.ReplicatedStorage.Shared.vide.MatchmakingHUD)


local function story(target: Instance)
		local _mainGui, mainControls, unmountMain = LobbyMainHUD.createLobbyMainHUD({
			title = "ALIEN INVASION",
			hintText = "Walk to a pad to play",
			parentGui = target,
		})
		if _mainGui ~= target then
			_mainGui.Parent = target
		end
		mainControls.setSilver(1250)
		mainControls.setGold(80)

		local matchmakingGui, matchmakingControls = MatchmakingHUD.createMatchmakingHUD({
			title = "ALIEN INVASION",
			statusText = "Click FIND MATCH to enter the queue.",
			buttonText = "FIND MATCH",
			onButtonClicked = function()
				matchmakingControls.setStatus("Searching for a match...")
				matchmakingControls.setButton("CANCEL", true)
			end,
			onShopClicked = function() end,
		})
		matchmakingGui.Parent = target
		matchmakingControls.setVisible(true)

		return function()
			if unmountMain then
				unmountMain()
			end
			matchmakingGui:Destroy()
		end
end

return story
