local ProfileService = require(script.Parent.Parent.ProfileService)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)	if not player then
		return Enum.ProductPurchaseDecision.NotYet
	end

	local success, err = pcall(function()
		ProfileService.buyDeveloperGold(player, receipt.ProductId)
	end)

	if success then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn("Failed to fulfill purchase (productId: " .. tostring(receipt.ProductId) .. "): " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotYet
	end
end
return true