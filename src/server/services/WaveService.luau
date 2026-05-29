--!strict
--------------------------------------------------------------------------------
-- WaveService.luau  (src/server/services)
-- Owns map cloning, gun distribution, and the wave progression loop.
-- Single Responsibility: wave lifecycle per player — no hit detection, no data.
--
-- Public API:
--   WaveService.startBattle(player) → number
--     Yields until the player dies or disconnects; returns final wave number.
--     Fires WaveAnnounce and WaveClear to the player via the Logger middleware.
--------------------------------------------------------------------------------

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework    = require(ReplicatedStorage.Shared.Framework)
local Logger       = require(ReplicatedStorage.Shared.Logger)
local Config       = require(ReplicatedStorage.Shared.Config)
local RemoteNames  = require(ReplicatedStorage.Shared.RemoteNames)
local ZombieService = require(script.Parent.ZombieService)
local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)
local ClerkInteractionModule = require(script.Parent.modules.wave.ClerkInteractionModule)
local LoadoutGrantModule = require(script.Parent.modules.wave.LoadoutGrantModule)

local TAG = "WaveService"

local WaveService = Framework.CreateService({ Name = TAG })

local _waveAnnounceRemote:       RemoteEvent
local _waveClearRemote:          RemoteEvent
local _openGunShopRemote:        RemoteEvent
local _requestGunPurchaseRemote: RemoteEvent
local _gunPurchaseResultRemote:  RemoteEvent
local _requestFreeLoadoutRemote: RemoteEvent
local _nextMapSlot:              number = 0

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function WaveService:Init()
	_waveAnnounceRemote       = Framework.CreateRemote(RemoteNames.WAVE_ANNOUNCE)
	_waveClearRemote          = Framework.CreateRemote(RemoteNames.WAVE_CLEAR)
	_openGunShopRemote        = Framework.CreateRemote(RemoteNames.OPEN_GUN_SHOP)
	_requestGunPurchaseRemote = Framework.CreateRemote(RemoteNames.REQUEST_GUN_PURCHASE)
	_gunPurchaseResultRemote  = Framework.CreateRemote(RemoteNames.GUN_PURCHASE_RESULT)
	_requestFreeLoadoutRemote = Framework.CreateRemote(RemoteNames.REQUEST_FREE_LOADOUT)
end

-- ── Private helpers ───────────────────────────────────────────────────────────

local function cloneMap(player: Player): Model?
	local template = ServerStorage:FindFirstChild(Config.MAP_NAME)
	if not template or not template:IsA("Model") then
		Logger.warn(TAG, "Map template '%s' not found in ServerStorage.", Config.MAP_NAME)
		return nil
	end
	local slot     = _nextMapSlot
	_nextMapSlot  += 1
	local map: Model = (template :: Model):Clone() :: Model
	map.Name   = Config.MAP_NAME .. "_" .. player.Name
	-- Space maps 4000 studs apart on the X axis to avoid overlap.
	map:PivotTo(CFrame.new(slot * 4000, 0, 5000))
	map.Parent = workspace
	return map
end

local function teleportToMap(player: Player, map: Model)
	local character = player.Character
	if not character then return end
	local spawnPart = map:FindFirstChild("Spawn_In", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		character:PivotTo((spawnPart :: BasePart).CFrame * CFrame.new(0, 5, 0))
	else
		character:PivotTo(map:GetPivot() * CFrame.new(0, 5, 0))
	end
end

local function getPlayerGunNames(player: Player): { string }
	local prices = Config.SHOP_GUN_PRICES :: { [string]: number }
	local guns: { string } = {}
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and prices[item.Name] ~= nil then
					table.insert(guns, item.Name)
				end
			end
		end
	end
	return guns
end

local function removeGunFromPlayer(player: Player, gunName: string)
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			local item = container:FindFirstChild(gunName)
			if item and item:IsA("Tool") then
				item:Destroy()
				return
			end
		end
	end
end

local function buildShopData(player: Player)
	local prices = Config.SHOP_GUN_PRICES :: { [string]: number }
	local available: { { name: string, price: number } } = {}
	for gunName, price in prices do
		table.insert(available, { name = gunName, price = price })
	end
	table.sort(available, function(a, b)
		return if a.price == b.price then a.name < b.name else a.price < b.price
	end)
	return {
		available     = available,
		currentGuns   = getPlayerGunNames(player),
		silverBalance = EconomyService.getRunSilver(player),
	}
end

local function giveGuns(player: Player)
	local allGunNames: { string } = { "M82", "Deagle", "M60", "M240B" }
	local unlockedGunNames: { string } = {}
	for _, gunName in ipairs(allGunNames) do
		if DataService.isWeaponUnlocked(player, gunName) then
			table.insert(unlockedGunNames, gunName)
		end
	end

	LoadoutGrantModule.grant(player, unlockedGunNames, function(message: string, ...: any)
		Logger.warn(TAG, message, ...)
	end)
end

local function findZombieSpawnPosition(map: Model): Vector3
	local spawnPart = map:FindFirstChild("Spawn_Mob", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		return (spawnPart :: BasePart).Position
	end
	return map:GetPivot().Position
end

local function getBattleHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
end

-- Runs one full wave: spawns all zombies, waits for all to die (or player death).
local function runWave(player: Player, waveNumber: number, spawnPos: Vector3, humanoid: Humanoid)
	Logger.info(TAG, "Wave %d — %s (%d zombies).", waveNumber, player.Name, waveNumber)
	player:SetAttribute("CurrentWave", waveNumber)

	-- All network sends go through Logger middleware for payload tracing.
	Logger.fireClient(_waveAnnounceRemote, player, waveNumber)

	local remaining = waveNumber
	local function onZombieDied() remaining -= 1 end

	for i = 1, waveNumber do
		if not player.Parent or humanoid.Health <= 0 then break end
		ZombieService.spawn(player, onZombieDied, spawnPos)
		if i < waveNumber then
			task.wait(Config.WAVE_SPAWN_INTERVAL)
		end
	end

	-- Polling loop: yield until all zombies are dead or the run is over.
	while remaining > 0 and player.Parent and humanoid.Health > 0 do
		task.wait(0.5)
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Run the full solo battle for one player. YIELDS until they die or disconnect.
--- Returns the last wave number reached (0 if the map or humanoid was unavailable).
function WaveService.startBattle(player: Player): number
	EconomyService.beginRun(player)
	player:SetAttribute("CurrentWave", Config.STARTING_WAVE)

	local map = cloneMap(player)
	if not map then return 0 end

	local humanoid = getBattleHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		map:Destroy()
		return 0
	end

	teleportToMap(player, map)
	local attached = ClerkInteractionModule.attach(map, player, function()
		Logger.fireClient(_openGunShopRemote, player, buildShopData(player))
	end)
	if not attached then
		Logger.warn(TAG, "shopClerk part not found in map '%s'.", map.Name)
	end

	local spawnPos   = findZombieSpawnPosition(map)
	local waveNumber = Config.STARTING_WAVE

	-- The humanoid reference is captured once. Even if the character respawns,
	-- this humanoid's Health drops to 0 on death, so the loop detects it correctly.
	while player.Parent and humanoid.Health > 0 do
		runWave(player, waveNumber, spawnPos, humanoid)

		if humanoid.Health <= 0 then
			Logger.info(TAG, "%s died on wave %d.", player.Name, waveNumber)
			ZombieService.cleanupForPlayer(player.Name)
			break
		end

		Logger.info(TAG, "Wave %d cleared for %s. Next in %ds.",
			waveNumber, player.Name, Config.WAVE_BETWEEN_DELAY)
		Logger.fireClient(_waveClearRemote, player)
		task.wait(Config.WAVE_BETWEEN_DELAY)
		waveNumber += 1
	end

	map:Destroy()
	player:SetAttribute("CurrentWave", nil)
	Logger.info(TAG, "Map cleaned up for %s. Final wave: %d.", player.Name, waveNumber)
	return waveNumber
end

function WaveService:Start()
	Logger.wrapServerEvent(_requestFreeLoadoutRemote, TAG, function(player: Player)
		giveGuns(player)
	end)

	Logger.wrapServerEvent(_requestGunPurchaseRemote, TAG, function(player: Player, buyGunName: any, replaceGunName: any)
		if type(buyGunName) ~= "string" then return end
		local prices = Config.SHOP_GUN_PRICES :: { [string]: number }
		local price = prices[buyGunName]
		if price == nil then
			Logger.fireClient(_gunPurchaseResultRemote, player, false, "UNKNOWN_GUN", EconomyService.getRunSilver(player))
			return
		end
		local currentGuns = getPlayerGunNames(player)
		if table.find(currentGuns, buyGunName) then
			Logger.fireClient(_gunPurchaseResultRemote, player, false, "ALREADY_OWNED", EconomyService.getRunSilver(player))
			return
		end
		local currentSilver = EconomyService.getRunSilver(player)
		if currentSilver < price then
			Logger.fireClient(_gunPurchaseResultRemote, player, false, "INSUFFICIENT_SILVER", currentSilver)
			return
		end
		if #currentGuns >= 2 then
			if type(replaceGunName) ~= "string" or not table.find(currentGuns, replaceGunName) then
				Logger.fireClient(_gunPurchaseResultRemote, player, false, "REPLACE_REQUIRED", currentSilver)
				return
			end
			removeGunFromPlayer(player, replaceGunName)
		end
		local _, newBalance = EconomyService.spendSilver(player, price)
		LoadoutGrantModule.grant(player, { buyGunName }, function(msg: string, ...: any)
			Logger.warn(TAG, msg, ...)
		end)
		Logger.info(TAG, "[GunShop] %s bought %s for %d Silver.", player.Name, buyGunName, price)
		Logger.fireClient(_gunPurchaseResultRemote, player, true, buyGunName, newBalance)
	end)
end

return WaveService
