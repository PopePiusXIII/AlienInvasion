--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework     = require(ReplicatedStorage.Shared.Framework)
local RemoteNames   = require(ReplicatedStorage.Shared.RemoteNames)
local GunShopModule = require(script.Parent.modules.wave.GunShopModule)

local TAG = "ShopController"
local ShopController = Framework.CreateController({ Name = TAG })

function ShopController:Start()
	local requestGunPurchaseRemote = Framework.GetRemote(RemoteNames.REQUEST_GUN_PURCHASE)
	local requestFreeLoadoutRemote = Framework.GetRemote(RemoteNames.REQUEST_FREE_LOADOUT)
	local openGunShopRemote        = Framework.GetRemote(RemoteNames.OPEN_GUN_SHOP)
	local gunPurchaseResultRemote  = Framework.GetRemote(RemoteNames.GUN_PURCHASE_RESULT)

	GunShopModule.init(requestGunPurchaseRemote, requestFreeLoadoutRemote)

	openGunShopRemote.OnClientEvent:Connect(function(shopData: any)
		GunShopModule.show(shopData)
	end)

	gunPurchaseResultRemote.OnClientEvent:Connect(function(success: any, message: any, newBalance: any)
		GunShopModule.onPurchaseResult(success :: boolean, message :: string, newBalance :: number)
	end)
end

return ShopController
