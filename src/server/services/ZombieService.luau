--!strict
--------------------------------------------------------------------------------
-- ZombieService.luau  (src/server/services)
-- Manages zombie spawning, AI chase loop, touch-damage, and death cleanup.
-- Single Responsibility: zombie lifecycle only. No RemoteEvents, no wave logic.
--
-- Public API:
--   ZombieService.spawn(target, onDied, centerPos?)  → spawns one zombie
--   ZombieService.damageZombie(model?, amount)       → server-authoritative damage
--   ZombieService.cleanupForPlayer(playerName)       → destroy all owned zombies
--------------------------------------------------------------------------------

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)

local TAG = "ZombieService"

export type OnDied = () -> ()

local ZombieService = Framework.CreateService({ Name = TAG })

local _zombieTemplates: { [string]: Model } = {}

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function ZombieService:Init()
	-- Cache every zombie template by type name at startup.
	local types = Config.ZOMBIE_TYPES :: { [string]: { Template: string } }
	for typeName, data in types do
		_zombieTemplates[typeName] = ServerStorage:WaitForChild(data.Template) :: Model
		Logger.info(TAG, "Zombie template cached: %s → %s", typeName, data.Template)
	end
end

-- ── Private helpers ───────────────────────────────────────────────────────────

local function resolveTemplate(zombieType: string): Model
	local template = _zombieTemplates[zombieType]
	if not template then
		Logger.warn(TAG, "Zombie template for type '%s' not found in ServerStorage; defaulting to '%s'.", zombieType, Config.ZOMBIE_DEFAULT_TYPE)
		template = _zombieTemplates[Config.ZOMBIE_DEFAULT_TYPE]
	end
	return template
end

local function cloneZombie(target: Player, zombieType: string): Model
	local zombie: Model = resolveTemplate(zombieType):Clone()
	zombie.Name = "Zombie"
	zombie:SetAttribute("Owner", target.Name)
	zombie:SetAttribute("ZombieType", zombieType)
	zombie.Parent = workspace
	return zombie
end

local function configureHumanoid(humanoid: Humanoid, maxHealth: number, walkSpeed: number)
	humanoid.MaxHealth       = maxHealth
	humanoid.Health          = maxHealth
	humanoid.WalkSpeed       = walkSpeed
	humanoid.AutoJumpEnabled = true
	humanoid.MaxSlopeAngle   = 90
end

local function placeAtSpawnPosition(zombie: Model, spawnPos: Vector3)
	local angle  = math.rad(math.random(0, 360))
	local spread = math.random(0, 3)
	zombie:PivotTo(CFrame.new(spawnPos + Vector3.new(
		math.cos(angle) * spread,
		Config.ZOMBIE_SPAWN_HEIGHT,
		math.sin(angle) * spread
	)))
end

local function setupTouchDamage(zombie: Model, humanoid: Humanoid, touchDamage: number)
	-- One shared cooldown flag per zombie — prevents burst damage on multi-part contact.
	local damageCooldown = false
	for _, descendant in ipairs(zombie:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local part: BasePart = descendant
			part.Anchored        = false
			part.CollisionGroup  = "Zombies"
			part.Touched:Connect(function(hit: BasePart)
				if damageCooldown then return end
				local hitModel = hit.Parent
				if not hitModel or hitModel.Name == "Zombie" then return end
				local playerHumanoid = hitModel:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
				if playerHumanoid and humanoid.Health > 0 then
					damageCooldown = true
					local zombieRoot = zombie:FindFirstChild("HumanoidRootPart") :: BasePart?
					local playerRoot = hitModel:FindFirstChild("HumanoidRootPart") :: BasePart?
					local dist = if zombieRoot and playerRoot
						then (zombieRoot.Position - playerRoot.Position).Magnitude
						else -1
					Logger.warn(TAG, "Touch hit: part='%s' hitModel='%s' dist=%.1f", part.Name, hitModel.Name, dist)
					playerHumanoid:TakeDamage(touchDamage)
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

-- Gives zombies a small upward impulse when a wall is detected ahead.
-- Prevents them from getting stuck on low obstacles.
local function applyWallClimb(zombieRoot: BasePart, zombie: Model, humanoid: Humanoid)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { zombie }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local rayOrigin = zombieRoot.Position + Vector3.new(0, 1, 0)
	local rayDir    = (zombieRoot.CFrame.LookVector + Vector3.new(0, 0.4, 0)).Unit * 5
	local result    = workspace:Raycast(rayOrigin, rayDir, params)

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
			local character  = target.Character
			local targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local zombieRoot = zombie:FindFirstChild("HumanoidRootPart") :: BasePart?
			if targetRoot and zombieRoot then
				humanoid:MoveTo(targetRoot.Position)
				applyWallClimb(zombieRoot, zombie, humanoid)
			end
			task.wait(Config.ZOMBIE_CHASE_INTERVAL)
		end
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Spawn a zombie that chases [target]. Calls [onDied] when it dies.
--- [centerPos] is the map spawn-point; omit to use world origin.
--- [zombieType] selects the variant; defaults to ZOMBIE_DEFAULT_TYPE.
function ZombieService.spawn(target: Player, onDied: OnDied, centerPos: Vector3?, zombieType: string?)
	local resolvedType = zombieType or Config.ZOMBIE_DEFAULT_TYPE
	local types = Config.ZOMBIE_TYPES :: { [string]: { MaxHealth: number, WalkSpeed: number, TouchDamage: number } }
	local stats = types[resolvedType] or types[Config.ZOMBIE_DEFAULT_TYPE]
	local zombie   = cloneZombie(target, resolvedType)
	local humanoid = zombie:FindFirstChildWhichIsA("Humanoid", true) :: Humanoid?
	if not humanoid then
		Logger.warn(TAG, "Zombie template '%s' is missing a Humanoid — skipping spawn.", resolvedType)
		zombie:Destroy()
		onDied()
		return
	end
	configureHumanoid(humanoid, stats.MaxHealth, stats.WalkSpeed)
	placeAtSpawnPosition(zombie, centerPos or Vector3.new(0, 0, 0))
	setupTouchDamage(zombie, humanoid, stats.TouchDamage)
	connectDeathCleanup(zombie, humanoid, onDied)
	startChaseLoop(zombie, humanoid, target)
end

--- Server-authoritative damage application.
--- Validates identity, parent, and Humanoid before taking damage.
--- NEVER trust the client to pass a valid model — always re-validate here.
function ZombieService.damageZombie(zombieModel: Model?, amount: number): (boolean, string, Vector3?)
	if not zombieModel then return false, Config.ZOMBIE_DEFAULT_TYPE, nil end
	if zombieModel.Name ~= "Zombie" then return false, Config.ZOMBIE_DEFAULT_TYPE, nil end
	if zombieModel.Parent ~= workspace then return false, Config.ZOMBIE_DEFAULT_TYPE, nil end
	local humanoid = zombieModel:FindFirstChildWhichIsA("Humanoid", true) :: Humanoid?
	if not humanoid then return false, Config.ZOMBIE_DEFAULT_TYPE, nil end
	if humanoid.Health <= 0 then
		return false, tostring(zombieModel:GetAttribute("ZombieType") or Config.ZOMBIE_DEFAULT_TYPE), nil
	end

	local healthBefore = humanoid.Health
	local rootPart = zombieModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	local deathPosition = if rootPart then rootPart.Position else zombieModel:GetPivot().Position
	humanoid:TakeDamage(amount)
	local zombieType = tostring(zombieModel:GetAttribute("ZombieType") or Config.ZOMBIE_DEFAULT_TYPE)
	local killed = healthBefore > 0 and amount >= healthBefore
	return killed, zombieType, killed and deathPosition or nil
end

--- Destroy all workspace zombies owned by [playerName].
function ZombieService.cleanupForPlayer(playerName: string)
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "Zombie" and obj:GetAttribute("Owner") == playerName then
			obj:Destroy()
		end
	end
end

return ZombieService
