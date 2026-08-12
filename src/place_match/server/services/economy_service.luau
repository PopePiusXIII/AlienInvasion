--!strict

local Players = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local EconomyConfig = require(replicated_storage.match.shared.configs.economy_config)
local ZombieConfig = require(replicated_storage.match.shared.configs.zombie_config)
local Framework     = require(replicated_storage.common.shared.framework)
local Logger        = require(replicated_storage.common.shared.logger)
local ProfileService = require(server_script_service.common.services.profile_db)

local EconomyService = {}
local TAG = "EconomyService"
EconomyService.Name = TAG

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
local _boltCollected = Instance.new("BindableEvent")
local _runCurrencyUpdatedRemote:  RemoteEvent
local _coinsEarnedUpdatedRemote:  RemoteEvent
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
			silverStuds  = math.max(0, math.floor(EconomyConfig.SILVER_START_BALANCE)),
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
	Logger.fireClient(_coinsEarnedUpdatedRemote, player, wallet.silverEarned)
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
	local byType = EconomyConfig.SILVER_DROP_BY_ZOMBIE_TYPE :: { [string]: { min: number, max: number } }
	local bucket = byType[zombieType] or byType[ZombieConfig.ZOMBIE_DEFAULT_TYPE] or { min = 1, max = 1 }
	local multiplier = 1 + (waveNumber - 1) * EconomyConfig.SILVER_WAVE_MULTIPLIER_STEP
	return math.max(1, math.round(randomInt(bucket.min, bucket.max) * multiplier))
end

local function rollGoldReward(zombieType: string, waveNumber: number): number
	local byType = EconomyConfig.GOLD_DROP_BY_ZOMBIE_TYPE :: { [string]: { chance: number, min: number, max: number } }
	local bucket = byType[zombieType] or byType[ZombieConfig.ZOMBIE_DEFAULT_TYPE]
	if not bucket then return 0 end
	local chance = math.clamp(bucket.chance * (1 + (waveNumber - 1) * EconomyConfig.GOLD_WAVE_CHANCE_STEP), 0, 1)
	if math.random() > chance then return 0 end
	local multiplier = 1 + (waveNumber - 1) * EconomyConfig.GOLD_WAVE_REWARD_STEP
	return math.max(1, math.round(randomInt(bucket.min, bucket.max) * multiplier))
end

-- Validate and process a client's claim that they collected a bolt.
local function onClaimBolt(player: Player, boltId: any)
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
	_boltCollected:Fire(player, record.currencyName, record.amount)
end

function EconomyService:Init()
	-- Templates are no longer used server-side; client handles all visuals.
	-- Warn if BoltTemplates is missing so the client can find them.
	if not replicated_storage:FindFirstChild("BoltTemplates") then
		Logger.warn(TAG, "replicated_storage.BoltTemplates folder not found — client bolt visuals will be missing.")
	end

	_runCurrencyUpdatedRemote  = Framework.CreateRemote("RunCurrencyUpdated")
	_coinsEarnedUpdatedRemote  = Framework.CreateRemote("CoinsAwarded")
	_requestShopPurchaseRemote = Framework.CreateRemote("PurchaseShopItem")
	_shopPurchaseResultRemote  = Framework.CreateRemote("ShopPurchaseResolved")
	_boltSpawnedRemote         = Framework.CreateRemote("BoltSpawned")
	_claimBoltRemote           = Framework.CreateRemote("ClaimBolt")

	Logger.onServerEvent(_claimBoltRemote, TAG, function(player: Player, boltId: any)
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
		silverStuds  = math.max(0, math.floor(EconomyConfig.SILVER_START_BALANCE)),
		silverEarned = 0,
		silverSpent  = 0,
		goldEarned   = 0, -- Only tracks gold earned during this run.
		persistentGold = persistentGold,
	}
	-- Clear any leftover bolt records from a previous run.
	_boltsByPlayer[player] = {}
	_nextBoltId[player] = 0
	syncWalletToClient(player)
	Logger.fireClient(_coinsEarnedUpdatedRemote, player, 0)
end

function EconomyService.grantKillRewards(player: Player, zombieType: string, waveNumber: number, deathPosition: Vector3?)
	local origin: Vector3
	if deathPosition then
		origin = deathPosition
	else
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

function EconomyService.getRunSilver(player: Player): number
	return getWallet(player).silverStuds
end

function EconomyService.onBoltCollected(callback: (Player, string, number) -> ()): RBXScriptConnection
	return _boltCollected.Event:Connect(callback)
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
	Logger.fireClient(_coinsEarnedUpdatedRemote, player, 0)
	_walletByPlayer[player] = nil
	return summary
end


Framework.CreateService(EconomyService)

return EconomyService
