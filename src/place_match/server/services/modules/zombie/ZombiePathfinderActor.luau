--!strict
--------------------------------------------------------------------------------
-- ZombiePathfinderActor.luau  (src/server/services/modules/zombie)
-- Owns the zombie chase/repulsion computation loop. The heavy repulsion math
-- runs in a parallel context (task.spawn(fn, true)) on a separate OS thread so
-- it doesn't block main-thread frame timing for player input or rendering.
--
-- Communication with ZombieService:
--   • ZombieService calls api.setSnapshots() each tick to feed fresh positions.
--   • This actor snapshots data, offloads computation to parallel context,
--     then applies MoveTo on the main thread.
--------------------------------------------------------------------------------

local PlayersService    = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Config = require(ReplicatedStorage.Shared.Config)

local TAG = "ZombiePathfinder"

-- ── Shared snapshot structure ────────────────────────────────────────────────
export type ZombieSnapshot = {
	rootPosition: Vector3?,
	humanoid: Humanoid,
}

-- ── Actor state ──────────────────────────────────────────────────────────────
local _snapshots: { ZombieSnapshot } = {}
local _running = false

-- Spatial hash grid (owned entirely by this actor).
-- Cell size is 2x repulsion distance so zombies actually distribute across
-- cells instead of all landing in the same one (which degenerates to O(n²)).
local CELL_SIZE: number = 0
local _grid: { [string]: { number } } = {}

-- Shared results table written by parallel context, read by main thread.
-- Each entry is { idx = number, target = Vector3 }.
local _moveTargets: { { idx: number, target: Vector3 } } = {}

-- Ready flag: parallel task sets this when computation is done.
local _ready = false

local function gridKey(cx: number, cz: number): string
	return cx .. "," .. cz
end

local function buildGrid(count: number, rootPositions: { [number]: Vector3 })
	_grid = {}
	for idx = 1, count do
		local pos = rootPositions[idx]
		if not pos then continue end
		local cx = math.floor(pos.X / CELL_SIZE)
		local cz = math.floor(pos.Z / CELL_SIZE)
		local key = gridKey(cx, cz)
		local cell = _grid[key]
		if cell then
			table.insert(cell, idx)
		else
			_grid[key] = { idx }
		end
	end
end

local function getNeighborIndices(idx: number, myPos: Vector3): { number }
	local cx = math.floor(myPos.X / CELL_SIZE)
	local cz = math.floor(myPos.Z / CELL_SIZE)
	local neighbors: { number } = {}
	for dx = -1, 1 do
		for dz = -1, 1 do
			local key = gridKey(cx + dx, cz + dz)
			local cell = _grid[key]
			if cell then
				for _, neighborIdx in ipairs(cell) do
					if neighborIdx ~= idx then
						table.insert(neighbors, neighborIdx)
					end
				end
			end
		end
	end
	return neighbors
end

-- ── Pure-math computation (runs in parallel context — no DataModel access) ───
-- Takes snapshot data, writes results into _moveTargets, then flips _ready.
local function computeMoveTargets(
	rootPositions: { [number]: Vector3 },
	playerPositions: { Vector3 },
	count: number
)
	-- Build spatial grid for O(n) repulsion lookups.
	buildGrid(count, rootPositions)

	_moveTargets = {}
	for idx = 1, count do
		local myPos = rootPositions[idx]
		if not myPos then continue end

		-- Find closest alive player to this zombie.
		local closestPlayerPos: Vector3? = nil
		local closestDistSq = math.huge
		for _, playerPos in ipairs(playerPositions) do
			local dx = myPos.X - playerPos.X
			local dz = myPos.Z - playerPos.Z
			local distSq = dx * dx + dz * dz
			if distSq < closestDistSq then
				closestDistSq = distSq
				closestPlayerPos = playerPos
			end
		end

		if not closestPlayerPos then continue end

		local dp = math.random(-1, 1)
		local moveTarget = closestPlayerPos + Vector3.new(dp, 0, dp)

		-- Repulsion from nearby zombies using spatial grid.
		local rx, rz = 0, 0
		local repDist = Config.ZOMBIE_REPULSION_DISTANCE
		local repForce = Config.ZOMBIE_REPULSION_FORCE
		for _, jdx in ipairs(getNeighborIndices(idx, myPos)) do
			local otherPos = rootPositions[jdx]
			if not otherPos then continue end
			local dx = myPos.X - otherPos.X
			local dz = myPos.Z - otherPos.Z
			local distSq = dx * dx + dz * dz
			if distSq < repDist * repDist and distSq > 0.0001 then
				local dist = math.sqrt(distSq)
				local strength = repForce * (1 - dist / repDist)
				rx += (dx / dist) * strength
				rz += (dz / dist) * strength
			end
		end
		moveTarget = moveTarget + Vector3.new(rx, 0, rz)

		table.insert(_moveTargets, { idx = idx, target = moveTarget })
	end

	_ready = true
end

-- ── Main chase loop (main thread: DataModel reads → parallel compute → writes) ──
local function chaseLoop()
	_running = true
	Logger.info(TAG, "Pathfinder running — repulsion math offloaded to parallel context.")

	while _running do
		-- Snapshot current state (shallow copy of positions + humanoid refs).
		local count = #_snapshots
		local rootPositions: { [number]: Vector3 } = table.create(count)
		local humanoids: { [number]: Humanoid } = table.create(count)

		for idx, snap in ipairs(_snapshots) do
			rootPositions[idx] = snap.rootPosition
			humanoids[idx] = snap.humanoid
		end

		-- Gather all alive player positions (DataModel read — must be on main thread).
		local playerPositions: { Vector3 } = {}
		for _, player in ipairs(PlayersService:GetPlayers()) do
			local character = player.Character
			if character then
				local targetRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if targetRoot then
					table.insert(playerPositions, targetRoot.Position)
				end
			end
		end

		-- Offload heavy repulsion math to parallel context (separate OS thread).
		_ready = false
		task.spawn(function()
			computeMoveTargets(rootPositions, playerPositions, count)
		end, true) -- true = parallel context

		-- Non-blocking wait: if computation isn't ready, skip this frame.
		-- Blocking here (while not _ready do task.wait() end) stalls the main thread,
		-- causing stutter that worsens with more zombies (2+ players, later waves).
		if not _ready then
			task.wait(Config.ZOMBIE_CHASE_INTERVAL)
			continue
		end

		-- Apply MoveTo on main thread (DataModel write).
		for _, result in ipairs(_moveTargets) do
			local humanoid = humanoids[result.idx]
			if humanoid and humanoid.Parent then
				humanoid:MoveTo(result.target)
			end
		end

		task.wait(Config.ZOMBIE_CHASE_INTERVAL)
	end

	Logger.info(TAG, "Pathfinder stopped.")
end

-- ── Public API ───────────────────────────────────────────────────────────────
local api = {}

--- Feed fresh zombie snapshots from the main thread.
--- Called by ZombieService each tick; shallow-copies for safety.
function api.setSnapshots(snaps: { ZombieSnapshot })
	_snapshots = snaps
end

--- Start the parallel chase loop (idempotent).
--- No Actor needed — uses task.spawn(fn, true) for parallel computation.
function api.start()
	if _running then return end
	CELL_SIZE = Config.ZOMBIE_REPULSION_DISTANCE * 2 -- Larger cells for better distribution.
	task.spawn(chaseLoop)
end

--- Stop the actor (called on service shutdown / cleanup).
function api.stop()
	_running = false
end

return api
