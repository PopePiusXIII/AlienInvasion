--!strict

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

type OnDied = () -> ()

local ZombieManager = {}

local zombieTemplate = ServerStorage:WaitForChild("Zombie")

local function cloneZombie(target: Player): Model
	local zombie: Model = zombieTemplate:Clone()
	zombie.Name = "Zombie"
	zombie:SetAttribute("Owner", target.Name)
	zombie.Parent = workspace
	return zombie
end

local function configureHumanoid(humanoid: Humanoid)
	humanoid.MaxHealth       = Config.ZOMBIE_MAX_HEALTH
	humanoid.Health          = Config.ZOMBIE_MAX_HEALTH
	humanoid.WalkSpeed       = Config.ZOMBIE_WALK_SPEED
	humanoid.AutoJumpEnabled = true
	humanoid.MaxSlopeAngle   = 90
end

local function placeAtSpawnPosition(zombie: Model, spawnPos: Vector3)
	local angle: number  = math.rad(math.random(0, 360))
	local spread: number = math.random(0, 3)
	zombie:PivotTo(CFrame.new(spawnPos + Vector3.new(
		math.cos(angle) * spread,
		Config.ZOMBIE_SPAWN_HEIGHT,
		math.sin(angle) * spread
	)))
end

local function setupTouchDamage(zombie: Model, humanoid: Humanoid)
	local damageCooldown: boolean = false
	for _, descendant: Instance in ipairs(zombie:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local part: BasePart = descendant
			part.Anchored        = false
			part.CollisionGroup  = "Zombies"
			part.Touched:Connect(function(hit: BasePart)
				if damageCooldown then return end
				local hitModel: Instance? = hit.Parent
				if not hitModel or hitModel.Name == "Zombie" then return end
				local playerHumanoid: Humanoid? = hitModel:FindFirstChildWhichIsA("Humanoid")
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
end

local function connectDeathCleanup(zombie: Model, humanoid: Humanoid, onDied: OnDied)
	humanoid.Died:Connect(function()
		task.wait(0.5)
		zombie:Destroy()
		onDied()
	end)
end

local function applyWallClimb(zombieRoot: BasePart, zombie: Model, humanoid: Humanoid)
	local params: RaycastParams = RaycastParams.new()
	params.FilterDescendantsInstances = { zombie }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local rayOrigin: Vector3     = zombieRoot.Position + Vector3.new(0, 1, 0)
	local rayDir: Vector3        = (zombieRoot.CFrame.LookVector + Vector3.new(0, 0.4, 0)).Unit * 5
	local result: RaycastResult? = workspace:Raycast(rayOrigin, rayDir, params)

	if result and result.Instance and result.Instance.CanCollide then
		zombieRoot.AssemblyLinearVelocity = Vector3.new(
			zombieRoot.AssemblyLinearVelocity.X,
			humanoid.WalkSpeed + 25,
			zombieRoot.AssemblyLinearVelocity.Z
		)
	end
end

local function startChaseLoop(zombie: Model, humanoid: Humanoid, target: Player)
	task.spawn(function()
		while zombie.Parent and humanoid.Health > 0 do
			local character: Model?     = target.Character
			local targetRoot: BasePart? = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local zombieRoot: BasePart? = zombie:FindFirstChild("HumanoidRootPart") :: BasePart?

			if targetRoot and zombieRoot then
				humanoid:MoveTo(targetRoot.Position)
				applyWallClimb(zombieRoot, zombie, humanoid)
			end
			task.wait(Config.ZOMBIE_CHASE_INTERVAL)
		end
	end)
end

function ZombieManager.spawn(target: Player, onDied: OnDied, centerPos: Vector3?): ()
	local zombie   = cloneZombie(target)
	local humanoid: Humanoid? = zombie:FindFirstChildWhichIsA("Humanoid", true)
	if not humanoid then
		warn("[ZombieManager] Zombie template is missing a Humanoid")
		zombie:Destroy()
		onDied()
		return
	end

	configureHumanoid(humanoid)
	placeAtSpawnPosition(zombie, centerPos or Vector3.new(0, 0, 0))
	setupTouchDamage(zombie, humanoid)
	connectDeathCleanup(zombie, humanoid, onDied)
	startChaseLoop(zombie, humanoid, target)
end

-- Server-side validation before applying gun damage reported by the client.
function ZombieManager.damageZombie(zombieModel: Model?, amount: number): ()
	if not zombieModel then return end
	if zombieModel.Name ~= "Zombie" then return end
	if zombieModel.Parent ~= workspace then return end

	local humanoid: Humanoid? = zombieModel:FindFirstChildWhichIsA("Humanoid", true)
	if not humanoid then return end

	humanoid:TakeDamage(amount)
end

return ZombieManager
