-- Handles spawning and behaviour of individual zombies.
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ZombieManager = {}

local zombieTemplate = ServerStorage:WaitForChild("Zombie")

-- Spawns one zombie that chases `target` (a Player).
-- Calls `onDied()` once when the zombie's health reaches zero.
-- `centerPos` is optional; defaults to world origin.
function ZombieManager.spawn(target, onDied, centerPos)
	centerPos = centerPos or Vector3.new(0, 0, 0)
	print("[ZombieManager] Spawning zombie for target: " .. target.Name)
	local zombie = zombieTemplate:Clone()
	zombie.Name = "Zombie"

	local humanoid = zombie:FindFirstChildWhichIsA("Humanoid", true)
	if not humanoid then
		warn("ZombieManager.spawn: Zombie template is missing a Humanoid")
		onDied()
		return
	end

	humanoid.MaxHealth       = Config.ZOMBIE_MAX_HEALTH
	humanoid.Health          = Config.ZOMBIE_MAX_HEALTH
	humanoid.WalkSpeed       = Config.ZOMBIE_WALK_SPEED
	humanoid.AutoJumpEnabled = true
	humanoid.MaxSlopeAngle   = 90

	zombie.Parent = workspace

	-- Spawn at fixed distance from center pos
	local angle  = math.rad(math.random(0, 360))
	local spawnX = math.cos(angle) * Config.ZOMBIE_SPAWN_DISTANCE
	local spawnZ = math.sin(angle) * Config.ZOMBIE_SPAWN_DISTANCE
	zombie:PivotTo(CFrame.new(centerPos) * CFrame.new(spawnX, Config.ZOMBIE_SPAWN_HEIGHT, spawnZ))

	-- Unanchor all parts and wire up touch damage in a single pass.
	local damageCooldown = false
	for _, part in ipairs(zombie:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Touched:Connect(function(hit)
				if damageCooldown then return end
				local hitModel = hit.Parent
				if hitModel.Name == "Zombie" then return end
				local playerHumanoid = hitModel:FindFirstChild("Humanoid")
				if playerHumanoid and humanoid.Health > 0 then
					damageCooldown = true
					playerHumanoid:TakeDamage(Config.ZOMBIE_TOUCH_DAMAGE)
					task.delay(Config.ZOMBIE_DAMAGE_COOLDOWN, function()
						damageCooldown = false
					end)
				end
			end)
		end
	end

	-- Notify caller and clean up when the zombie dies.
	humanoid.Died:Connect(function()
		task.wait(0.5)
		zombie:Destroy()
		onDied()
	end)

	-- Direct chase loop: move toward the player every ZOMBIE_CHASE_INTERVAL seconds.
	task.spawn(function()
		while zombie.Parent and humanoid.Health > 0 do
			local character = target.Character
			local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
			local zombieRoot = zombie:FindFirstChild("HumanoidRootPart")

			if targetRoot and zombieRoot then
				humanoid:MoveTo(targetRoot.Position)

				-- Spider Logic: If stuck against a wall, float up it
				local forwardParams = RaycastParams.new()
				forwardParams.FilterDescendantsInstances = {zombie}
				forwardParams.FilterType = Enum.RaycastFilterType.Exclude
				
				-- Look ahead and slightly up
				local rayOrigin = zombieRoot.Position + Vector3.new(0, 1, 0)
				local rayDir    = (zombieRoot.CFrame.LookVector + Vector3.new(0, 0.4, 0)).Unit * 5
				local rayResult = workspace:Raycast(rayOrigin, rayDir, forwardParams)
				
				if rayResult and rayResult.Instance and rayResult.Instance.CanCollide then
					-- Apply vertical lift
					zombieRoot.AssemblyLinearVelocity = Vector3.new(
						zombieRoot.AssemblyLinearVelocity.X,
						Config.ZOMBIE_WALK_SPEED + 25,
						zombieRoot.AssemblyLinearVelocity.Z
					)
				end
			end
			task.wait(Config.ZOMBIE_CHASE_INTERVAL)
		end
	end)
end

-- Applies laser damage to a zombie model sent by the client.
-- Validates the model on the server before touching any health values.
function ZombieManager.damageZombie(zombieModel, amount)
	if not zombieModel then return end
	if zombieModel.Name ~= "Zombie" then return end
	if zombieModel.Parent ~= workspace then return end

	local humanoid = zombieModel:FindFirstChildWhichIsA("Humanoid", true)
	if not humanoid then return end

	humanoid:TakeDamage(amount)
end

return ZombieManager
