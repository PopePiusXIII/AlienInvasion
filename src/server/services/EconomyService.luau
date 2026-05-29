--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local TAG = "EconomyService"
local EconomyService = Framework.CreateService({ Name = TAG })

export type RunWallet = {
	silverStuds: number,
	silverEarned: number,
	silverSpent: number,
	goldEarned: number,
}

local _walletByPlayer: { [Player]: RunWallet } = {}
local _runCurrencyUpdatedRemote: RemoteEvent
local _requestShopPurchaseRemote: RemoteEvent
local _shopPurchaseResultRemote: RemoteEvent
local _silverBoltTemplate: Instance?
local _goldBoltTemplate: Instance?

local BOLT_LIFETIME    = 14
local MAX_SILVER_BOLTS = 10
local MAX_GOLD_BOLTS   = 6

local function randomInt(min: number, max: number): number
	return math.random(math.floor(min), math.max(math.floor(min), math.floor(max)))
end

local function getWallet(player: Player): RunWallet
	if not _walletByPlayer[player] then
		_walletByPlayer[player] = {
			silverStuds  = math.max(0, math.floor(Config.SILVER_START_BALANCE)),
			silverEarned = 0,
			silverSpent  = 0,
			goldEarned   = 0,
		}
	end
	return _walletByPlayer[player]
end

local function syncWalletToClient(player: Player)
	Logger.fireClient(_runCurrencyUpdatedRemote, player, getWallet(player).silverStuds)
end

local function awardSilver(player: Player, amount: number)
	local gain = math.max(0, math.floor(amount))
	if gain <= 0 then return end
	local wallet = getWallet(player)
	wallet.silverStuds += gain
	wallet.silverEarned += gain
	syncWalletToClient(player)
end

local function awardGold(player: Player, amount: number)
	local gain = math.max(0, math.floor(amount))
	if gain <= 0 then return end
	getWallet(player).goldEarned += gain
end

local function distributeIntoBolts(total: number, boltCount: number): { number }
	local chunks: { number } = table.create(boltCount, 1)
	local remaining = total
	for i = 1, boltCount do
		local left = boltCount - i + 1
		if left == 1 then
			chunks[i] = remaining
			break
		end
		local value = randomInt(1, remaining - (left - 1))
		chunks[i] = value
		remaining -= value
	end
	return chunks
end

local function moveBolt(bolt: Instance, capturedRoot: BasePart, newPos: Vector3)
	if bolt:IsA("Model") then
		(bolt :: Model):MoveTo(newPos)
	else
		capturedRoot.CFrame = CFrame.new(newPos)
	end
end

local function spawnBoltPickup(currencyName: string, player: Player, amount: number, spawnPosition: Vector3): boolean
	local template = if currencyName == "Silver" then _silverBoltTemplate else _goldBoltTemplate
	if not template then return false end

	local bolt = template:Clone()
	bolt.Name = currencyName .. "BoltPickup"

	local parts: { BasePart } = {}
	local rootPart: BasePart? = nil

	if bolt:IsA("BasePart") then
		local p = bolt :: BasePart
		p.Anchored = true; p.CanCollide = false; p.CanTouch = true
		p.CFrame = CFrame.new(spawnPosition)
		rootPart = p
		table.insert(parts, p)
	elseif bolt:IsA("Model") then
		for _, d in ipairs((bolt :: Model):GetDescendants()) do
			if d:IsA("BasePart") then
				local p = d :: BasePart
				p.Anchored = true; p.CanCollide = false; p.CanTouch = true; p.Transparency = 0
				if not rootPart then rootPart = p end
				table.insert(parts, p)
			end
		end
		if not rootPart then bolt:Destroy(); return false end
	else
		bolt:Destroy(); return false
	end

	bolt.Parent = workspace
	if bolt:IsA("Model") then (bolt :: Model):MoveTo(spawnPosition) end

	local capturedRoot = rootPart :: BasePart
	local boltCenter: Vector3
	if bolt:IsA("Model") then
		local cf, _ = (bolt :: Model):GetBoundingBox()
		boltCenter = cf.Position
	else
		boltCenter = capturedRoot.Position
	end

	local hoverY = spawnPosition.Y + Config.BOLT_HOVER_HEIGHT
	local riseElapsed = 0
	local riseComplete = false
	local attractSpeed = 0
	local collected = false
	local touchConns: { RBXScriptConnection } = {}
	local heartbeatConn: RBXScriptConnection? = nil

	local function collectBolt()
		if collected then return end
		collected = true
		if heartbeatConn then heartbeatConn:Disconnect() end
		for _, c in ipairs(touchConns) do c:Disconnect() end
		if currencyName == "Silver" then awardSilver(player, amount) else awardGold(player, amount) end
		Logger.info(TAG, "[%s] +%d collected by %s.", currencyName, amount, player.Name)
		if bolt.Parent then bolt:Destroy() end
	end

	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		if not bolt.Parent or collected then
			if heartbeatConn then heartbeatConn:Disconnect() end
			return
		end
		riseElapsed += dt
		if not riseComplete then
			local t = math.min(riseElapsed / Config.BOLT_RISE_DURATION, 1)
			local easedY = spawnPosition.Y + (hoverY - spawnPosition.Y) * (1 - (1 - t)^2)
			boltCenter = Vector3.new(boltCenter.X, easedY, boltCenter.Z)
			moveBolt(bolt, capturedRoot, boltCenter)
			if t >= 1 then riseComplete = true end
			return
		end
		local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not playerRoot then return end
		local toPlayer = playerRoot.Position - boltCenter
		if toPlayer.Magnitude <= Config.BOLT_ATTRACT_RADIUS then
			attractSpeed = math.min(attractSpeed + Config.BOLT_ATTRACT_ACCELERATION * dt, 40)
			if toPlayer.Magnitude > 0.5 then
				boltCenter = boltCenter + toPlayer.Unit * attractSpeed * dt
				moveBolt(bolt, capturedRoot, boltCenter)
			end
		else
			attractSpeed = 0
			local bobY = hoverY + math.sin(os.clock() * 2) * 0.3
			boltCenter = Vector3.new(boltCenter.X, bobY, boltCenter.Z)
			moveBolt(bolt, capturedRoot, boltCenter)
		end
	end)

	for _, p in ipairs(parts) do
		table.insert(touchConns, p.Touched:Connect(function(hit: BasePart)
			if not collected and Players:GetPlayerFromCharacter(hit.Parent) == player then
				collectBolt()
			end
		end))
	end

	Debris:AddItem(bolt, BOLT_LIFETIME)
	return true
end

local function spawnBoltBurst(currencyName: string, player: Player, amount: number, origin: Vector3)
	local maxBolts = if currencyName == "Gold" then MAX_GOLD_BOLTS else MAX_SILVER_BOLTS
	local boltCount = math.clamp(amount, 1, maxBolts)
	for _, chunk in ipairs(distributeIntoBolts(amount, boltCount)) do
		local ox = math.random(-4, 4)
		local oz = math.random(-4, 4)
		spawnBoltPickup(currencyName, player, chunk, origin + Vector3.new(ox, 0, oz))
	end
end

local function calculateSilverReward(zombieType: string, waveNumber: number): number
	local byType = Config.SILVER_DROP_BY_ZOMBIE_TYPE :: { [string]: { min: number, max: number } }
	local bucket = byType[zombieType] or byType[Config.ZOMBIE_DEFAULT_TYPE] or { min = 1, max = 1 }
	local multiplier = 1 + (waveNumber - 1) * Config.SILVER_WAVE_MULTIPLIER_STEP
	return math.max(1, math.round(randomInt(bucket.min, bucket.max) * multiplier))
end

local function rollGoldReward(zombieType: string, waveNumber: number): number
	local byType = Config.GOLD_DROP_BY_ZOMBIE_TYPE :: { [string]: { chance: number, min: number, max: number } }
	local bucket = byType[zombieType] or byType[Config.ZOMBIE_DEFAULT_TYPE]
	if not bucket then return 0 end
	local chance = math.clamp(bucket.chance * (1 + (waveNumber - 1) * Config.GOLD_WAVE_CHANCE_STEP), 0, 1)
	if math.random() > chance then return 0 end
	local multiplier = 1 + (waveNumber - 1) * Config.GOLD_WAVE_REWARD_STEP
	return math.max(1, math.round(randomInt(bucket.min, bucket.max) * multiplier))
end

function EconomyService:Init()
	_silverBoltTemplate = ServerStorage:FindFirstChild("SilverBolt", true)
	_goldBoltTemplate   = ServerStorage:FindFirstChild("GoldBolt", true)

	if not _silverBoltTemplate then Logger.warn(TAG, "SilverBolt not found in ServerStorage.") end
	if not _goldBoltTemplate   then Logger.warn(TAG, "GoldBolt not found in ServerStorage.") end

	_runCurrencyUpdatedRemote  = Framework.CreateRemote(RemoteNames.RUN_CURRENCY_UPDATED)
	_requestShopPurchaseRemote = Framework.CreateRemote(RemoteNames.REQUEST_SHOP_PURCHASE)
	_shopPurchaseResultRemote  = Framework.CreateRemote(RemoteNames.SHOP_PURCHASE_RESULT)

	Logger.wrapServerEvent(_requestShopPurchaseRemote, TAG, function(player: Player, productId: string)
		EconomyService._onPurchaseRequest(player, productId)
	end)
end

function EconomyService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		_walletByPlayer[player] = nil
	end)
end

function EconomyService.beginRun(player: Player)
	_walletByPlayer[player] = {
		silverStuds  = math.max(0, math.floor(Config.SILVER_START_BALANCE)),
		silverEarned = 0,
		silverSpent  = 0,
		goldEarned   = 0,
	}
	syncWalletToClient(player)
end

function EconomyService.grantKillRewards(player: Player, zombieType: string, waveNumber: number, deathPosition: Vector3?)
	local origin = deathPosition
	if not origin then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then return end
		origin = root.Position
	end

	spawnBoltBurst("Silver", player, calculateSilverReward(zombieType, waveNumber), origin)

	local goldAmount = rollGoldReward(zombieType, waveNumber)
	if goldAmount > 0 then
		spawnBoltBurst("Gold", player, goldAmount, origin)
	end
end

function EconomyService._onPurchaseRequest(player: Player, productId: string)
	if type(productId) ~= "string" or productId == "" then
		Logger.fireClient(_shopPurchaseResultRemote, player, false, "INVALID_PRODUCT", 0)
		return
	end

	local price = (Config.SHOP_SILVER_PRICES :: { [string]: number })[productId]
	if not price then
		Logger.fireClient(_shopPurchaseResultRemote, player, false, "UNKNOWN_PRODUCT", 0)
		return
	end

	local wallet = getWallet(player)
	if wallet.silverStuds < price then
		Logger.fireClient(_shopPurchaseResultRemote, player, false, "INSUFFICIENT_SILVER", wallet.silverStuds)
		return
	end

	wallet.silverStuds -= price
	wallet.silverSpent += price
	syncWalletToClient(player)
	Logger.fireClient(_shopPurchaseResultRemote, player, true, productId, wallet.silverStuds)
end

function EconomyService.getRunSilver(player: Player): number
	return getWallet(player).silverStuds
end

function EconomyService.finalizeRun(player: Player): { silverEarned: number, silverSpent: number, goldEarned: number }
	local wallet = getWallet(player)
	local summary = { silverEarned = wallet.silverEarned, silverSpent = wallet.silverSpent, goldEarned = wallet.goldEarned }
	_walletByPlayer[player] = nil
	return summary
end

return EconomyService
