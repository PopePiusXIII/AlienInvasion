--!strict
local Players = game:GetService("Players")

local GunShopModule = {}

local _localPlayer = Players.LocalPlayer

local _requestGunPurchaseRemote: RemoteEvent
local _requestFreeLoadoutRemote: RemoteEvent

local _mainFrame:       Frame
local _silverLabel:     TextLabel
local _loadoutFrame:    Frame
local _availableFrame:  Frame
local _swapPickerFrame: Frame
local _statusLabel:     TextLabel

local _pendingBuyGun: string? = nil
local _currentGuns:   { string } = {}

local C_BG      = Color3.fromRGB(18,  18,  26)
local C_PANEL   = Color3.fromRGB(32,  32,  46)
local C_ACCENT  = Color3.fromRGB(255, 195, 50)
local C_GREEN   = Color3.fromRGB(60,  180, 80)
local C_RED     = Color3.fromRGB(200, 60,  60)
local C_SUBTEXT = Color3.fromRGB(140, 140, 160)
local C_WHITE   = Color3.new(1, 1, 1)

local function addCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeLabel(parent: Instance, text: string, size: UDim2, pos: UDim2, fontSize: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Text = text; l.Size = size; l.Position = pos
	l.BackgroundTransparency = 1
	l.TextColor3 = color; l.TextSize = fontSize
	l.Font = Enum.Font.GothamBold
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function makeButton(parent: Instance, text: string, size: UDim2, pos: UDim2, bg: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Text = text; b.Size = size; b.Position = pos
	b.BackgroundColor3 = bg; b.TextColor3 = C_WHITE
	b.TextSize = 13; b.Font = Enum.Font.GothamBold
	b.BorderSizePixel = 0; b.AutoButtonColor = true
	b.Parent = parent
	addCorner(b, 4)
	return b
end

local function makeDivider(parent: Instance, y: number)
	local d = Instance.new("Frame")
	d.Size = UDim2.new(1, -32, 0, 1)
	d.Position = UDim2.new(0, 16, 0, y)
	d.BackgroundColor3 = C_PANEL
	d.BorderSizePixel = 0
	d.Parent = parent
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GunShopGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = _localPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Main"
	-- Larger shop UI so longer gun lists (MP5/SCAR) are visible
	frame.Size = UDim2.new(0, 640, 0, 640)
	frame.Position = UDim2.new(0.5, -320, 0.5, -320)
	frame.BackgroundColor3 = C_BG
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	addCorner(frame, 10)
	_mainFrame = frame

	makeLabel(frame, "GUN SHOP", UDim2.new(0, 180, 0, 38), UDim2.new(0, 16, 0, 10), 20, C_ACCENT)

	_silverLabel = makeLabel(frame, "◈ 0", UDim2.new(0, 155, 0, 38), UDim2.new(0, 200, 0, 10), 15, C_ACCENT)
	_silverLabel.TextXAlignment = Enum.TextXAlignment.Right

	local closeBtn = makeButton(frame, "✕", UDim2.new(0, 34, 0, 34), UDim2.new(1, -46, 0, 8), Color3.fromRGB(90, 35, 35))
	closeBtn.MouseButton1Click:Connect(GunShopModule.hide)

	makeDivider(frame, 54)

	makeLabel(frame, "CURRENT LOADOUT", UDim2.new(1, -32, 0, 18), UDim2.new(0, 16, 0, 60), 10, C_SUBTEXT)

	local lf = Instance.new("Frame")
	lf.Name = "Loadout"; lf.Size = UDim2.new(1, -32, 0, 48); lf.Position = UDim2.new(0, 16, 0, 80)
	lf.BackgroundTransparency = 1; lf.Parent = frame
	_loadoutFrame = lf

	makeDivider(frame, 134)

	makeLabel(frame, "AVAILABLE GUNS", UDim2.new(1, -32, 0, 18), UDim2.new(0, 16, 0, 140), 10, C_SUBTEXT)

	local af = Instance.new("Frame")
	af.Name = "Available"; af.Size = UDim2.new(1, -32, 0, 396); af.Position = UDim2.new(0, 16, 0, 162)
	af.BackgroundTransparency = 1; af.Parent = frame
	_availableFrame = af
	_statusLabel = makeLabel(frame, "", UDim2.new(1, -32, 0, 18), UDim2.new(0, 16, 0, 563), 13, C_RED)
	_statusLabel.TextXAlignment = Enum.TextXAlignment.Center

	makeDivider(frame, 586)

	local freeBtn = makeButton(frame, "Get Free Loadout", UDim2.new(0, 183, 0, 36), UDim2.new(0, 16, 0, 594), Color3.fromRGB(45, 65, 115))
	freeBtn.MouseButton1Click:Connect(function()
		_requestFreeLoadoutRemote:FireServer()
		_statusLabel.Text = "Loadout refreshed!"
		_statusLabel.TextColor3 = C_GREEN
	end)

	local closeFooterBtn = makeButton(frame, "Close", UDim2.new(0, 183, 0, 36), UDim2.new(1, -199, 0, 594), C_PANEL)
	closeFooterBtn.MouseButton1Click:Connect(GunShopModule.hide)

	local sp = Instance.new("Frame")
	sp.Name = "SwapPicker"; sp.Size = UDim2.new(1, 0, 0, 134); sp.Position = UDim2.new(0, 0, 0.5, -67)
	sp.BackgroundColor3 = Color3.fromRGB(12, 12, 22); sp.BorderSizePixel = 0
	sp.Visible = false; sp.ZIndex = 10
	sp.Parent = frame
	addCorner(sp, 8)
	_swapPickerFrame = sp

	local swapLabel = makeLabel(sp, "Replace which gun?", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 12), 15, C_WHITE)
	swapLabel.TextXAlignment = Enum.TextXAlignment.Center
	swapLabel.ZIndex = 11
end

local function rebuildLoadoutSlots()
	for _, c in ipairs(_loadoutFrame:GetChildren()) do c:Destroy() end
	for i = 1, 2 do
		local sf = Instance.new("Frame")
		sf.Size = UDim2.new(0.5, -6, 1, 0)
		sf.Position = UDim2.new((i - 1) * 0.5, i == 1 and 0 or 6, 0, 0)
		sf.BackgroundColor3 = C_PANEL; sf.BorderSizePixel = 0; sf.Parent = _loadoutFrame
		addCorner(sf, 4)
		makeLabel(sf, "Slot " .. i, UDim2.new(1, -8, 0, 16), UDim2.new(0, 8, 0, 4), 10, C_SUBTEXT)
		makeLabel(sf, _currentGuns[i] or "— Empty", UDim2.new(1, -8, 0, 22), UDim2.new(0, 8, 0, 20), 14, C_WHITE)
	end
end

local function showSwapPicker()
	for _, c in ipairs(_swapPickerFrame:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end

	local count = #_currentGuns
	for i, gunName in ipairs(_currentGuns) do
		local xOff = if count == 1 then 130 else (i == 1 and 16 or 224)
		local btn = makeButton(_swapPickerFrame, "Replace " .. gunName, UDim2.new(0, 170, 0, 36), UDim2.new(0, xOff, 0, 50), C_RED)
		btn.ZIndex = 11
		local captured = gunName
		btn.MouseButton1Click:Connect(function()
			_swapPickerFrame.Visible = false
			if _pendingBuyGun then
				_requestGunPurchaseRemote:FireServer(_pendingBuyGun, captured)
			end
			_pendingBuyGun = nil
		end)
	end

	local cancelBtn = makeButton(_swapPickerFrame, "Cancel", UDim2.new(0, 80, 0, 26), UDim2.new(0.5, -40, 1, -34), C_PANEL)
	cancelBtn.ZIndex = 11
	cancelBtn.MouseButton1Click:Connect(function()
		_swapPickerFrame.Visible = false
		_pendingBuyGun = nil
	end)

	_swapPickerFrame.Visible = true
end

local function rebuildAvailableGuns(available: { { name: string, price: number } }, silverBalance: number)
	for _, c in ipairs(_availableFrame:GetChildren()) do c:Destroy() end

	for i, gun in ipairs(available) do
		local rf = Instance.new("Frame")
		rf.Size = UDim2.new(1, 0, 0, 48); rf.Position = UDim2.new(0, 0, 0, (i - 1) * 54)
		rf.BackgroundColor3 = C_PANEL; rf.BorderSizePixel = 0; rf.Parent = _availableFrame
		addCorner(rf, 4)

		makeLabel(rf, gun.name, UDim2.new(0, 130, 1, 0), UDim2.new(0, 12, 0, 0), 15, C_WHITE)

		local priceText = if gun.price == 0 then "Free" else ("◈ " .. gun.price)
		local priceColor = if gun.price == 0 then C_GREEN else C_ACCENT
		makeLabel(rf, priceText, UDim2.new(0, 95, 1, 0), UDim2.new(0, 148, 0, 0), 14, priceColor)

		local owned = table.find(_currentGuns, gun.name) ~= nil
		local canAfford = silverBalance >= gun.price
		local btnBg = if owned then C_PANEL elseif canAfford then Color3.fromRGB(40, 140, 65) else Color3.fromRGB(110, 40, 40)
		local btnText = if owned then "Owned" else "Buy"
		local buyBtn = makeButton(rf, btnText, UDim2.new(0, 78, 0, 32), UDim2.new(1, -90, 0.5, -16), btnBg)

		if not owned then
			local capturedGun = gun.name
			buyBtn.MouseButton1Click:Connect(function()
				if not canAfford then
					_statusLabel.Text = "Not enough Silver!"
					_statusLabel.TextColor3 = C_RED
					return
				end
				_statusLabel.Text = ""
				if #_currentGuns >= 2 then
					_pendingBuyGun = capturedGun
					showSwapPicker()
				else
					_requestGunPurchaseRemote:FireServer(capturedGun)
				end
			end)
		end
	end
end

type ShopData = {
	available:     { { name: string, price: number } },
	currentGuns:   { string },
	silverBalance: number,
}

function GunShopModule.init(requestGunPurchaseRemote: RemoteEvent, requestFreeLoadoutRemote: RemoteEvent)
	_requestGunPurchaseRemote = requestGunPurchaseRemote
	_requestFreeLoadoutRemote = requestFreeLoadoutRemote
	buildGui()
end

function GunShopModule.show(shopData: ShopData)
	_currentGuns = shopData.currentGuns
	_pendingBuyGun = nil
	_swapPickerFrame.Visible = false
	_statusLabel.Text = ""
	_silverLabel.Text = "◈ " .. shopData.silverBalance
	rebuildLoadoutSlots()
	rebuildAvailableGuns(shopData.available, shopData.silverBalance)
	_mainFrame.Visible = true
end

function GunShopModule.hide()
	_mainFrame.Visible = false
	_swapPickerFrame.Visible = false
	_pendingBuyGun = nil
end

function GunShopModule.onPurchaseResult(success: boolean, message: string, newBalance: number)
	_swapPickerFrame.Visible = false
	_pendingBuyGun = nil
	if success then
		_silverLabel.Text = "◈ " .. newBalance
		_statusLabel.Text = message .. " purchased!"
		_statusLabel.TextColor3 = C_GREEN
		task.delay(0.8, GunShopModule.hide)
	else
		_statusLabel.TextColor3 = C_RED
		_statusLabel.Text = if message == "INSUFFICIENT_SILVER" then "Not enough Silver!"
			elseif message == "ALREADY_OWNED" then "You already have this gun!"
			else "Purchase failed."
	end
end

return GunShopModule
