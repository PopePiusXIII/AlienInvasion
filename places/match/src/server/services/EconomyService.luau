--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework      = require(ReplicatedStorage.Shared.Framework)
local Logger         = require(ReplicatedStorage.Shared.Logger)
local ProfileService = require(ReplicatedStorage.Shared.ProfileService)
local Config         = require(ReplicatedStorage.Shared.Config)
local RemoteNames    = require(ReplicatedStorage.Shared.RemoteNames)

local TAG = "EconomyService"
local EconomyService = Framework.CreateService({ Name = TAG })

-- Minimal server-side record: just enough to validate a CLAIM_BOLT request.
type BoltRecord = {
	id:           number,
	currencyName: string,
	amount:       number,
	spawnPos:     Vector3,
	claimed:      boolean,
}

-- One map per player: bolt id → BoltRecord.
local _boltsByPlayer: { [Player]: { [number]: BoltRecord } } = {}
local _nextBoltId: { [Player]: number } = {}

export type RunWallet = {
	silverStuds: number,
	silverEarned: number,
	silverSpent: number,
	goldEarned: number,
	persistentGold: number, -- Snapshot of profile gold at run start.
}

local _walletByPlayer: { [Player]: RunWallet } = {}
local _runCurrencyUpdatedRemote:  RemoteEvent
local _requestShopPurchaseRemote: RemoteEvent
local _shopPurchaseResultRemote:  RemoteEvent
local _boltSpawnedRemote:         RemoteEvent
local _claimBoltRemote:           RemoteEvent

local BOLT_LIFETIME    = 10
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
			persistentGold = 0,
		}
	end
	return _walletByPlayer[player]
end

local function syncWalletToClient(player: Player)
	local wallet = getWallet(player)
	-- Total gold = cached persistent balance + newly earned this run.
	local totalGold = wallet.persistentGold + wallet.goldEarned
	Logger.fireClient(_runCurrencyUpdatedRemote, player, wallet.silverStuds, totalGold)
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
	syncWalletToClient(player)
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

-- Notifies the client to spawn and animate a bolt locally.
-- Nothing is created in workspace — the client owns the visual.
local function notifyBoltSpawn(currencyName: string, player: Player, amount: number, spawnPosition: Vector3)
	local bolts = _boltsByPlayer[player]
	if not bolts then return end

	local id = (_nextBoltId[player] or 0) + 1
	_nextBoltId[player] = id

	local record: BoltRecord = {
		id           = id,
		currencyName = currencyName,
		amount       = amount,
		spawnPos     = spawnPosition,
		claimed      = false,
	}
	bolts[id] = record

	-- Tell the client exactly what it needs to render the bolt.
	Logger.fireClient(_boltSpawnedRemote, player, id, currencyName, amount, spawnPosition)

	-- Auto-expire the server record after the bolt lifetime.
	task.delay(BOLT_LIFETIME, function()
		if bolts[id] then
			bolts[id] = nil
		end
	end)
end

local function spawnBoltBurst(currencyName: string, player: Player, amount: number, origin: Vector3)
	local maxBolts = if currencyName == "Gold" then MAX_GOLD_BOLTS else MAX_SILVER_BOLTS
	local boltCount = math.clamp(amount, 1, maxBolts)
	for _, chunk in ipairs(distributeIntoBolts(amount, boltCount)) do
		local ox = math.random(-4, 4)
		local oz = math.random(-4, 4)
		notifyBoltSpawn(currencyName, player, chunk, origin + Vector3.new(ox, 0, oz))
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

-- Validate and process a client's claim that they collected a bolt.
local function onClaimBolt(player: Player, boltId: unknown)
	if type(boltId) ~= "number" then return end

	local bolts = _boltsByPlayer[player]
	if not bolts then return end

	local record = bolts[boltId]
	if not record or record.claimed then return end

	-- Bolts are already scoped per-player (_boltsByPlayer[player]), so only the owning
	-- player can claim them. The client-side attraction physics means bolts can drift
	-- far from their spawn position before collection, making a strict distance check
	-- counterproductive. Trust the per-player ownership model instead.

	record.claimed = true
	bolts[boltId] = nil

	if record.currencyName == "Silver" then
		awardSilver(player, record.amount)
	else
		awardGold(player, record.amount)
	end
end

function EconomyService:Init()
	-- Templates are no longer used server-side; client handles all visuals.
	-- Warn if BoltTemplates is missing so the client can find them.
	if not ReplicatedStorage:FindFirstChild("BoltTemplates") then
		Logger.warn(TAG, "ReplicatedStorage.BoltTemplates folder not found — client bolt visuals will be missing.")
	end

	_runCurrencyUpdatedRemote  = Framework.CreateRemote(RemoteNames.RUN_CURRENCY_UPDATED)
	_requestShopPurchaseRemote = Framework.CreateRemote(RemoteNames.REQUEST_SHOP_PURCHASE)
	_shopPurchaseResultRemote  = Framework.CreateRemote(RemoteNames.SHOP_PURCHASE_RESULT)
	_boltSpawnedRemote         = Framework.CreateRemote(RemoteNames.BOLT_SPAWNED)
	_claimBoltRemote           = Framework.CreateRemote(RemoteNames.CLAIM_BOLT)

	Logger.wrapServerEvent(_requestShopPurchaseRemote, TAG, function(player: Player, productId: string)
		EconomyService._onPurchaseRequest(player, productId)
	end)

	Logger.wrapServerEvent(_claimBoltRemote, TAG, function(player: Player, boltId: unknown)
		onClaimBolt(player, boltId)
	end)
end

function EconomyService:Start()
	local function onPlayerAdded(player: Player)
		_boltsByPlayer[player] = {}
		_nextBoltId[player] = 0
	end	

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		-- Flush gold earned this run to the persistent profile.
		local wallet = _walletByPlayer[player]
		if wallet and wallet.goldEarned > 0 then
			local profile = ProfileService:GetProfile(player)
			if profile then
				profile.goldStuds += wallet.goldEarned
			end
		end

		_walletByPlayer[player] = nil
		_boltsByPlayer[player] = nil
		_nextBoltId[player] = nil
	end)

	-- Handle players already in the server at startup.
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

function EconomyService.beginRun(player: Player)
	-- Snapshot the persistent gold once at run start so syncWalletToClient
	-- doesn't block on ProfileService during the wave loop.
	local profile = ProfileService:GetProfile(player)
	local persistentGold = profile and profile.goldStuds or 0

	_walletByPlayer[player] = {
		silverStuds  = math.max(0, math.floor(Config.SILVER_START_BALANCE)),
		silverEarned = 0,
		silverSpent  = 0,
		goldEarned   = 0, -- Only tracks gold earned during this run.
		persistentGold = persistentGold,
	}
	-- Clear any leftover bolt records from a previous run.
	_boltsByPlayer[player] = {}
	_nextBoltId[player] = 0
	syncWalletToClient(player)
end

function EconomyService.grantKillRewards(player: Player, zombieType: string, waveNumber: number, deathPosition: Vector3?)
	local origin = deathPosition
	if not origin then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then return end
		origin = root.Position
	end

	local silverAmount = calculateSilverReward(zombieType, waveNumber)
	local goldAmount   = rollGoldReward(zombieType, waveNumber)

	Logger.info(TAG, "Kill reward — type=%s wave=%d silver=%d gold=%d", zombieType, waveNumber, silverAmount, goldAmount)

	-- Every active player gets their own bolt copy to collect — shared kill reward.
	for _, recipient in ipairs(Players:GetPlayers()) do
		if not _boltsByPlayer[recipient] then continue end
		spawnBoltBurst("Silver", recipient, silverAmount, origin)
		if goldAmount > 0 then
			spawnBoltBurst("Gold", recipient, goldAmount, origin)
		end
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

function EconomyService.spendSilver(player: Player, amount: number): (boolean, number)
	local cost = math.max(0, math.floor(amount))
	local wallet = getWallet(player)
	if wallet.silverStuds < cost then return false, wallet.silverStuds end
	if cost > 0 then
		wallet.silverStuds -= cost
		wallet.silverSpent += cost
		syncWalletToClient(player)
	end
	return true, wallet.silverStuds
end

function EconomyService.finalizeRun(player: Player): { silverEarned: number, silverSpent: number, goldEarned: number }
	local wallet = getWallet(player)
	local summary = { silverEarned = wallet.silverEarned, silverSpent = wallet.silverSpent, goldEarned = wallet.goldEarned }
	Logger.fireClient(_runCurrencyUpdatedRemote, player, 0)
	_walletByPlayer[player] = nil
	return summary
end

return EconomyService
