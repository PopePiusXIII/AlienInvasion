local server_script_service = game:GetService("ServerScriptService")
local ProfileService = require(server_script_service.common.services.profile_db)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)	
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local success, err = pcall(function()
		ProfileService.buyDeveloperGold(player, receipt.ProductId)
	end)

	if success then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn("Failed to fulfill purchase (productId: " .. tostring(receipt.ProductId) .. "): " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end
return true
