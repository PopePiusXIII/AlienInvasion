--!strict
--------------------------------------------------------------------------------
-- ZombieController (client)
-- Smooths zombie movement by interpolating positions between network updates.
-- Without this, zombies appear to stutter/jerk as Roblox replicates MoveTo
-- positions at discrete intervals.
--
-- Smooths ALL zombies — for ones the client owns (via SetNetworkOwner on server),
-- the lerp delta is tiny so it's effectively a no-op. For other players' zombies,
-- this smooths out replication lag stutter.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger = require(ReplicatedStorage.Shared.Logger)

local TAG = "ZombieController"
local ZombieController = Framework.CreateController({ Name = TAG })

-- Interpolation smoothing factor (0-1). Higher = snappier, lower = smoother.
-- 0.15 gives good balance between responsiveness and smoothness at ~60fps.
local SMOOTH_FACTOR = 0.15

type ZombieSmoothEntry = {
	model: Model,
	rootPart: BasePart,
	trackedCFrame: CFrame?,      -- Current interpolated position
	isNew: boolean,              -- True if just spawned (teleport to target first)
}

local _smoothedZombies: { ZombieSmoothEntry } = {}
local _zombieMap: { [Instance]: ZombieSmoothEntry } = {}

--- Find or create a smoothing entry for a zombie model.
local function getOrCreateEntry(zombie: Model): ZombieSmoothEntry?
	if _zombieMap[zombie] then
		return _zombieMap[zombie]
	end

	local rootPart = zombie:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		Logger.warn(TAG, "Zombie %q has no HumanoidRootPart, skipping smoothing.", zombie:GetFullName())
		return nil
	end

	local entry: ZombieSmoothEntry = {
		model = zombie,
		rootPart = rootPart,
		trackedCFrame = rootPart.CFrame,
		isNew = true,
	}

	_zombieMap[zombie] = entry
	table.insert(_smoothedZombies, entry)
	return entry
end

--- Remove a zombie from the smoothing table.
local function removeEntry(zombie: Model): nil
	local entry = _zombieMap[zombie]
	if not entry then return end

	_zombieMap[zombie] = nil
	for i = #_smoothedZombies, 1, -1 do
		if _smoothedZombies[i] == entry then
			table.remove(_smoothedZombies, i)
			return
		end
	end
end

function ZombieController:Init()
	-- Nothing to initialize.
end

function ZombieController:Start()
	local workspace = game:GetService("Workspace")

	-- Register any existing zombies at startup.
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "Zombie" and child:IsA("Model") then
			getOrCreateEntry(child :: Model)
		end
	end

	-- Watch for future spawns/despawns.
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Zombie" and child:IsA("Model") then
			getOrCreateEntry(child :: Model)
		end
	end)

	workspace.ChildRemoved:Connect(function(child)
		if _zombieMap[child] then
			removeEntry(child :: Model)
		end
	end)

	-- Smooth interpolation loop runs every frame on the client.
	RunService.RenderStepped:Connect(function()
		for i = #_smoothedZombies, 1, -1 do
			local entry = _smoothedZombies[i]

			-- Validate the zombie still exists.
			if not entry.model.Parent then
				removeEntry(entry.model)
				continue
			end

			-- Sample the "real" network position from the root part.
			local realCFrame = entry.rootPart.CFrame

			if entry.isNew then
				-- First frame: snap to target immediately (no interpolation needed).
				entry.trackedCFrame = realCFrame
				entry.isNew = false
				continue
			end

			-- Lerp tracked position toward the real network position,
			-- then apply the smoothed CFrame.
			if entry.trackedCFrame then
				entry.trackedCFrame = entry.trackedCFrame:Lerp(realCFrame, SMOOTH_FACTOR)
				entry.rootPart.CFrame = entry.trackedCFrame
			end
		end
	end)

	Logger.info(TAG, "Zombie smoothing active.")
end

return ZombieController
