--!strict

local LobbyMainHUD = require(game.replicated_storage.shared.vide.LobbyMainHUD)
local MatchmakingHUD = require(game.replicated_storage.shared.vide.MatchmakingHUD)
local ProfileApi = require(game.ServerStorage.Shared.UiLabsApi)


local function story(target: Instance)
		local _mainGui, mainControls, unmountMain = LobbyMainHUD.createLobbyMainHUD({
			title = "ALIEN INVASION",
			hintText = "Walk to a pad to play",
			parentGui = target,
			onPurchaseWeapon = ProfileApi.purchaseWeapon,
		})
		if _mainGui ~= target then
			_mainGui.Parent = target
		end
		local unsubscribeProfile = ProfileApi.onChanged(function(profile)
			mainControls.setSilver(profile.silver)
			mainControls.setGold(profile.gold)
		end)
		ProfileApi.start()

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
			unsubscribeProfile()
			if unmountMain then
				unmountMain()
			end
			matchmakingGui:Destroy()
		end
end

return story
