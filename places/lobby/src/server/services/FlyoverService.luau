--!strict
--------------------------------------------------------------------------------
-- FlyoverService.luau  (places/lobby/src/server/services)
-- Detects a part named "flyover" in the Workspace and moves it continuously.
-- Usually used for decorative planes or UFOs in the lobby.
--------------------------------------------------------------------------------

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)

local TAG = "FlyoverService"

local FlyoverService = Framework.CreateService({ Name = TAG })

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function FlyoverService:Init()
	Logger.info(TAG, "Initializing FlyoverService...")
end

function FlyoverService:Start()
	-- Wait for the game to fully load/Initialize sequence to finish
	task.wait(2)
	
	-- Search for a folder/model named "flyover" that contains our planes
	local container = workspace:FindFirstChild("flyover", true)

	if not container then
		Logger.warn(TAG, "Container 'flyover' not found via direct search. Scanning desk...")
		for _, child in ipairs(workspace:GetDescendants()) do
			if child.Name:lower() == "flyover" then
				container = child
				break
			end
		end
	end

	if not container then
		Logger.error(TAG, "FAILED: No object named 'flyover' found in Workspace. Ensure you have a folder/model named 'flyover'.")
		return
	end

	Logger.info(TAG, "Attached to flyover container: %s", container:GetFullName())

	local velocity = Config.FLYOVER_VELOCITY or 100
	local loopDelay = Config.FLYOVER_LOOP_DELAY or 20

	-- Store initial transforms so we can reset them every loop
	local initialTransforms: { [Instance]: CFrame } = {}
	for _, object in ipairs(container:GetChildren()) do
		if object.Name:lower() == "plane" then
			if object:IsA("Model") then
				initialTransforms[object] = object:GetPivot()
				Logger.info(TAG, "Found plane model: %s", object.Name)
			elseif object:IsA("BasePart") then
				initialTransforms[object] = object.CFrame
				Logger.info(TAG, "Found plane part: %s", object.Name)
			end
		end
	end

	local planeCount = 0
	for _ in pairs(initialTransforms) do planeCount += 1 end

	if planeCount == 0 then
		Logger.warn(TAG, "Flyover container '%s' exists but has no children named 'plane'.", container.Name)
		return
	end

	task.spawn(function()
		while true do
			Logger.info(TAG, ">>> LOOP START (%d planes, Velocity %d, Delay %ds)", planeCount, velocity, loopDelay)
			
			-- ── Global Audio ──
			local containerSound = container:FindFirstChildOfClass("Sound")
			if containerSound then
				containerSound.Looped = false
				containerSound:Play()
				Logger.info(TAG, "Playing global Sound: %s", containerSound.Name)
			elseif container:FindFirstChildWhichIsA("Sound", true) then
				local s = container:FindFirstChildWhichIsA("Sound", true)
				if s then
					s.Looped = false
					s:Play()
					Logger.info(TAG, "Playing nested Sound: %s", s.Name)
				end
			end

			-- Start planes
			local connections: { RBXScriptConnection } = {}
			for object, startCFrame in initialTransforms do
				-- Reset to start
				if object:IsA("Model") then
					object:PivotTo(startCFrame)
				elseif object:IsA("BasePart") then
					object.CFrame = startCFrame
				end

				-- Start movement
				local conn = self:_startPlaneMovement(object, velocity)
				if conn then table.insert(connections, conn) end
			end

			-- Wait for the loop duration
			task.wait(loopDelay)

			-- Cleanup connections before next loop
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end)
end

function FlyoverService:_startPlaneMovement(plane: Instance, velocity: number): RBXScriptConnection?
	local primaryPart: BasePart?
	
	if plane:IsA("Model") then
		primaryPart = plane.PrimaryPart or plane:FindFirstChildWhichIsA("BasePart", true)
	elseif plane:IsA("BasePart") then
		primaryPart = plane
	end

	if not primaryPart then
		Logger.error(TAG, "Plane '%s' contains no BasePart to drive movement.", plane:GetFullName())
		return nil
	end

	-- ── Audio ──
	local sound = plane:FindFirstChildOfClass("Sound", true)
	if sound then
		sound.Looped = false
		sound:Play()
	end

	-- ── Movement ──
	local connection: RBXScriptConnection
	if primaryPart.Anchored then
		connection = RunService.Heartbeat:Connect(function(dt)
			-- Flip direction: changed from -velocity (forward) to +velocity (backward)
			local moveStep = CFrame.new(0, 0, velocity * dt)
			if plane:IsA("Model") then
				plane:PivotTo(plane:GetPivot() * moveStep)
			else
				(plane :: BasePart).CFrame = (plane :: BasePart).CFrame * moveStep
			end
		end)
	else
		connection = RunService.Heartbeat:Connect(function()
			-- Flip direction: changed from LookVector to -LookVector
			primaryPart.AssemblyLinearVelocity = -primaryPart.CFrame.LookVector * velocity
			primaryPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end)
	end

	return connection
end

return FlyoverService
