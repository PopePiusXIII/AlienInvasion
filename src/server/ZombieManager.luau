-- Handles spawning and behaviour of individual zombies.
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ZombieManager = {}

local zombieTemplate = ServerStorage:WaitForChild("Zombie")

-- Spawns one zombie that chases `target` (a Player).
-- Calls `onDied()` once when the zombie's health reaches zero.
function ZombieManager.spawn(target, onDied)
	local zombie = zombieTemplate:Clone()
	zombie.Name = "Zombie"

	local humanoid = zombie:FindFirstChildWhichIsA("Humanoid", true)
	if not humanoid then
		warn("ZombieManager.spawn: Zombie template is missing a Humanoid")
		onDied()
		return
	end

	humanoid.MaxHealth = Config.ZOMBIE_MAX_HEALTH
	humanoid.Health    = Config.ZOMBIE_MAX_HEALTH
	humanoid.WalkSpeed = Config.ZOMBIE_WALK_SPEED

	zombie.Parent = workspace

	local spawnX = math.random(-Config.ZOMBIE_SPAWN_RADIUS, Config.ZOMBIE_SPAWN_RADIUS)
	local spawnZ = math.random(-Config.ZOMBIE_SPAWN_RADIUS, Config.ZOMBIE_SPAWN_RADIUS)
	zombie:PivotTo(CFrame.new(spawnX, Config.ZOMBIE_SPAWN_HEIGHT, spawnZ))

	-- Store models are often anchored; unanchor so the Humanoid can move them.
	for _, part in ipairs(zombie:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	-- Damage any player character that touches the zombie.
	-- Ignore self-collisions and zombie-on-zombie contact.
	local damageCooldown = false
	for _, part in ipairs(zombie:GetDescendants()) do
		if part:IsA("BasePart") then
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

	-- Continuously chase the target; refresh MoveTo before its 8-second timeout.
	task.spawn(function()
		while zombie.Parent and humanoid.Health > 0 do
			local character = target.Character
			if character then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root then
					humanoid:MoveTo(root.Position)
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
