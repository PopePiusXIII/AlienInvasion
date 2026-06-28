--!strict
-- BoltController
-- Owns all bolt visual rendering on the client.
-- Receives BOLT_SPAWNED from the server, animates bolts locally each RenderStepped
-- (no replication lag), then fires CLAIM_BOLT when the local character touches one.
-- The server validates and awards currency.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RenderScheduler = require(ReplicatedStorage.Shared.RenderScheduler)

local Framework = require(ReplicatedStorage.Shared.Framework)
local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local TAG = "BoltController"
local BoltController = Framework.CreateController({ Name = TAG })

type ClientBoltState = {
	id:           number,
	bolt:         Instance,
	root:         BasePart,
	center:       Vector3,
	hoverY:       number,
	spawnY:       number,
	riseElapsed:  number,
	riseComplete: boolean,
	attractSpeed: number,
	claimed:      boolean,
	spawnTime:    number,
}

local _activeBolts: { ClientBoltState } = {}
local _boltTaskId: string? = nil
local _silverTemplate: Instance?
local _goldTemplate:   Instance?

local _boltSpawnedRemote: RemoteEvent
local _claimBoltRemote:   RemoteEvent

local _localPlayer: Player

-- Must match the server-side BOLT_LIFETIME so client visuals expire in sync.
local BOLT_LIFETIME = 10

local function moveBolt(bolt: Instance, root: BasePart, pos: Vector3)
	if bolt:IsA("Model") then
		(bolt :: Model):PivotTo(CFrame.new(pos))
	else
		root.CFrame = CFrame.new(pos)
	end
end

local function claimBolt(state: ClientBoltState)
	if state.claimed then return end
	state.claimed = true
	if state.bolt.Parent then state.bolt:Destroy() end
	_claimBoltRemote:FireServer(state.id)
end

local function onBoltSpawned(id: number, currencyName: string, _amount: number, spawnPosition: Vector3)
	local template = if currencyName == "Silver" then _silverTemplate else _goldTemplate
	if not template then return end

	local bolt = template:Clone()
	bolt.Name = currencyName .. "BoltPickup_" .. tostring(id)

	local rootPart: BasePart? = nil

	if bolt:IsA("BasePart") then
		local p = bolt :: BasePart
		p.Anchored = true; p.CanCollide = false; p.CanTouch = false
		p.CFrame = CFrame.new(spawnPosition)
		rootPart = p
	elseif bolt:IsA("Model") then
		for _, d in ipairs((bolt :: Model):GetDescendants()) do
			if d:IsA("BasePart") then
				local p = d :: BasePart
				p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.Transparency = 0
				if not rootPart then rootPart = p end
			end
		end
		if not rootPart then bolt:Destroy(); return end
	else
		bolt:Destroy(); return
	end

	bolt.Parent = workspace

	if bolt:IsA("Model") then
		(bolt :: Model):MoveTo(spawnPosition)
	end

	local boltCenter: Vector3
	if bolt:IsA("Model") then
		local cf, _ = (bolt :: Model):GetBoundingBox()
		boltCenter = cf.Position
	else
		boltCenter = (rootPart :: BasePart).Position
	end

	local state: ClientBoltState = {
		id           = id,
		bolt         = bolt,
		root         = rootPart :: BasePart,
		center       = boltCenter,
		hoverY       = spawnPosition.Y + (Config.BOLT_HOVER_HEIGHT :: number),
		spawnY       = spawnPosition.Y,
		riseElapsed  = 0,
		riseComplete = false,
		attractSpeed = 0,
		claimed      = false,
		spawnTime    = tick(),
	}
	table.insert(_activeBolts, state)
	if _boltTaskId then
		RenderScheduler.setEnabled(_boltTaskId, true)
	end
end

function BoltController:Init()
	_localPlayer = Players.LocalPlayer

	local templates = ReplicatedStorage:FindFirstChild("BoltTemplates")
	if templates then
		_silverTemplate = templates:FindFirstChild("SilverBolt")
		_goldTemplate   = templates:FindFirstChild("GoldBolt")
	end

	_boltSpawnedRemote = Framework.GetRemote(RemoteNames.BOLT_SPAWNED)
	_claimBoltRemote   = Framework.GetRemote(RemoteNames.CLAIM_BOLT)
end

function BoltController:Start()
	_boltSpawnedRemote.OnClientEvent:Connect(function(id: number, currencyName: string, amount: number, spawnPosition: Vector3)
		onBoltSpawned(id, currencyName, amount, spawnPosition)
	end)

	local riseDuration = Config.BOLT_RISE_DURATION :: number
	local attrRad      = Config.BOLT_ATTRACT_RADIUS :: number
	local attrAccel    = Config.BOLT_ATTRACT_ACCELERATION :: number
	local collectRad   = Config.BOLT_COLLECT_RADIUS :: number

	_boltTaskId = RenderScheduler.register("bolts", function(dt: number)
		if #_activeBolts == 0 then
			RenderScheduler.setEnabled(_boltTaskId, false)
			return
		end

		local character = _localPlayer.Character
		local rootPart  = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local playerPos: Vector3? = rootPart and (rootPart :: BasePart).Position

		-- Iterate in reverse so safe in-place removal works.
		local i = #_activeBolts
		while i > 0 do
			local s = _activeBolts[i]

			-- Purge if already claimed, model was destroyed externally, or bolt has expired.
			if s.claimed or not s.bolt.Parent or (tick() - s.spawnTime) >= BOLT_LIFETIME then
				if s.bolt.Parent then s.bolt:Destroy() end
				_activeBolts[i] = _activeBolts[#_activeBolts]
				_activeBolts[#_activeBolts] = nil
				i -= 1
				continue
			end

			if not s.riseComplete then
				-- Rise phase: ease-out quad from spawn Y to hover Y.
				s.riseElapsed += dt
				local t = math.min(s.riseElapsed / riseDuration, 1)
				local easedY = s.spawnY + (s.hoverY - s.spawnY) * (1 - (1 - t) ^ 2)
				s.center = Vector3.new(s.center.X, easedY, s.center.Z)
				if t >= 1 then s.riseComplete = true end
			elseif playerPos then
				local dx = playerPos.X - s.center.X
				local dy = playerPos.Y - s.center.Y
				local dz = playerPos.Z - s.center.Z
				local mag = math.sqrt(dx * dx + dy * dy + dz * dz)

				-- Collection check — distance-based, no server round-trip needed.
				if mag <= collectRad then
					claimBolt(s)
					_activeBolts[i] = _activeBolts[#_activeBolts]
					_activeBolts[#_activeBolts] = nil
					i -= 1
					continue
				end

				-- Attraction phase: accelerate toward player within attract radius.
				if mag <= attrRad then
					s.attractSpeed = math.min(s.attractSpeed + attrAccel * dt, 40)
					if mag > 0.5 then
						local inv = s.attractSpeed * dt / mag
						s.center = Vector3.new(s.center.X + dx * inv, s.center.Y + dy * inv, s.center.Z + dz * inv)
					end
				else
					s.attractSpeed = 0
				end
			end

			moveBolt(s.bolt, s.root, s.center)
			i -= 1
		end
	end, { enabled = false })
end

return BoltController
