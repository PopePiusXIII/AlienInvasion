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
local PhysicsService    = game:GetService("PhysicsService")
local PlayersService    = game:GetService("Players")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)
local ZombiePathfinderActor = require(script.Parent.modules.zombie.ZombiePathfinderActor)

local TAG = "ZombieService"

export type OnDied = () -> ()

local ZombieService = Framework.CreateService({ Name = TAG })

local _zombieTemplates: { [string]: Model } = {}

type ZombieEntry = { zombie: Model, humanoid: Humanoid, target: Player }
local _activeZombies: { ZombieEntry } = {}

-- ── Snapshot feeder (main thread) ────────────────────────────────────────────
-- Purges dead zombies and feeds fresh position snapshots to the desynchronized
-- pathfinder actor. The heavy repulsion math runs off the main thread.
local function snapshotFeederLoop()
	while true do
		-- Serial: purge dead / removed zombies (DataModel writes — must stay on main thread).
		local i = #_activeZombies
		while i > 0 do
			local entry = _activeZombies[i]
			if not entry.zombie.Parent or entry.humanoid.Health <= 0 then
				_activeZombies[i] = _activeZombies[#_activeZombies]
				_activeZombies[#_activeZombies] = nil
			end
			i -= 1
		end

		-- Snapshot zombie root positions and feed to the desynchronized actor.
		local snapshots: { ZombiePathfinderActor.ZombieSnapshot } = {}
		for _, entry in ipairs(_activeZombies) do
			local root = entry.zombie:FindFirstChild("HumanoidRootPart") :: BasePart?
			table.insert(snapshots, {
				rootPosition = root and root.Position or nil,
				humanoid = entry.humanoid,
			})
		end
		ZombiePathfinderActor.setSnapshots(snapshots)

		task.wait(Config.ZOMBIE_CHASE_INTERVAL)
	end
end

local function setupZombieCollision(zombieModel: Model): nil
    for _, part: Instance in ipairs(zombieModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = "Zombies"
        end
    end
    return nil
end

local function disableZombieDisplay(zombieModel: Model): nil
    local humanoid: Humanoid? = zombieModel:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        -- This hides the health bar entirely
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        
        -- This ensures the Name/Display name never shows up by setting its render distance to 0
        humanoid.NameDisplayDistance = 0
    end
    return nil
end

function ZombieService:Init()
	-- Cache every zombie template by type name at startup.
	local types = Config.ZOMBIE_TYPES :: { [string]: { Template: string } }
	for typeName, data in types do
		_zombieTemplates[typeName] = ServerStorage:WaitForChild(data.Template) :: Model
		Logger.info(TAG, "Zombie template cached: %s → %s", typeName, data.Template)
		setupZombieCollision(_zombieTemplates[typeName])
		disableZombieDisplay(_zombieTemplates[typeName])
	end

	-- Ensure the group exists
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Zombies")
		PhysicsService:CollisionGroupSetCollidable("Zombies", "Zombies", false)
	end)
end

function ZombieService:Start()
	-- Start parallel pathfinder actor (handles repulsion + MoveTo off main thread).
	ZombiePathfinderActor.start()

	-- Lightweight snapshot feeder stays on main thread for DataModel safety.
	task.spawn(snapshotFeederLoop)
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
	local spread = math.random(0, 60)
	zombie:PivotTo(CFrame.new(spawnPos + Vector3.new(
		0.0,
		Config.ZOMBIE_SPAWN_HEIGHT,
		spread
	)))
end

local function setupTouchDamage(zombie: Model, humanoid: Humanoid, touchDamage: number)
	-- Single listener on one arm — avoids N listeners per zombie.
	local touchPart = (zombie:FindFirstChild("Right Arm")
		or zombie:FindFirstChild("Left Arm")
		or zombie:FindFirstChild("RightHand")
		or zombie:FindFirstChild("LeftHand")
		or zombie:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not touchPart then return end

	local damageCooldown = false
	touchPart.Touched:Connect(function(hit: BasePart)
		if damageCooldown then return end
		local hitModel = hit.Parent
		if not hitModel or hitModel.Name == "Zombie" then return end
		local playerHumanoid = hitModel:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
		if playerHumanoid and humanoid.Health > 0 then
			damageCooldown = true
			playerHumanoid:TakeDamage(touchDamage)
			task.delay(Config.ZOMBIE_DAMAGE_COOLDOWN, function()
				damageCooldown = false
			end)
		end
	end)
end

-- ── Death cleanup (NO ragdoll, NO piece explosion — just wait & destroy) ──
local function applyKnockback(zombieModel: Model, knockbackForce: number, shooterPos: Vector3?)
	local rootPart = zombieModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart or not shooterPos then return end
	local direction = (rootPart.Position - shooterPos).Unit
	rootPart.Velocity = direction * knockbackForce
	-- Store the knockback direction so ragdoll can reuse it on death.
	zombieModel:SetAttribute("KnockbackDirX", direction.X)
	zombieModel:SetAttribute("KnockbackDirY", direction.Y)
	zombieModel:SetAttribute("KnockbackDirZ", direction.Z)
end

local function ragdollAndExplode(zombieModel: Model, explosionForce: number)
	-- Disable the humanoid so joints don't restore pose
	local humanoid = zombieModel:FindFirstChildWhichIsA("Humanoid", true) :: Humanoid?
	if humanoid then
		humanoid.BreakJointsOnDeath = false -- we handle it manually
	end

	-- Break all welds so body parts become independent
	for _, descendant in ipairs(zombieModel:GetDescendants()) do
		if descendant:IsA("WeldConstraint") or descendant:IsA("Weld") or descendant:IsA("ManualWeld") then
			descendant:Destroy()
		end
	end

	-- Recover the shot direction from the last knockback (or fall back to straight up).
	local dirX = zombieModel:GetAttribute("KnockbackDirX") :: number?
	local dirY = zombieModel:GetAttribute("KnockbackDirY") :: number?
	local dirZ = zombieModel:GetAttribute("KnockbackDirZ") :: number?
	local shotDir: Vector3
	if dirX and dirY and dirZ then
		shotDir = Vector3.new(dirX, dirY, dirZ)
	else
		shotDir = Vector3.yAxis
	end

	-- Throw each body part along the shot direction with a small randomized spread.
	for _, part in ipairs(zombieModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = true

			-- Dampen inherited knockback velocity so pieces don't fly off too far,
			-- then add an impulse along the shot direction plus small random spread.
			part.Velocity = part.Velocity * 0.15 + shotDir * explosionForce 

		end
	end
end

local function connectDeathCleanup(zombie: Model, humanoid: Humanoid, onDied: OnDied)
	humanoid.Died:Connect(function()
		ragdollAndExplode(zombie, 30)
		task.wait(2.0)
		zombie:Destroy()
		onDied()
	end)
end

local function registerZombie(zombie: Model, humanoid: Humanoid, target: Player)
	table.insert(_activeZombies, { zombie = zombie, humanoid = humanoid, target = target })
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
	registerZombie(zombie, humanoid, target)
end

--- Server-authoritative damage application.
--- Validates identity, parent, and Humanoid before taking damage.
--- NEVER trust the client to pass a valid model — always re-validate here.
function ZombieService.damageZombie(zombieModel: Model?, gunName: string?, isHeadshot: boolean?, shooterPos: Vector3?): (boolean, string, Vector3?)
	if not zombieModel then return false, Config.ZOMBIE_DEFAULT_TYPE, nil end
	if zombieModel.Name ~= "Zombie" then return false, Config.ZOMBIE_DEFAULT_TYPE, nil end
	if zombieModel.Parent ~= workspace then return false, Config.ZOMBIE_DEFAULT_TYPE, nil end
	local humanoid = zombieModel:FindFirstChildWhichIsA("Humanoid", true) :: Humanoid?
	if not humanoid then return false, Config.ZOMBIE_DEFAULT_TYPE, nil end
	if humanoid.Health <= 0 then return false, tostring(zombieModel:GetAttribute("ZombieType") or Config.ZOMBIE_DEFAULT_TYPE), nil end

	-- Resolve gun stats internally — caller just passes the gun name.
	local statsByName = Config.GUN_STATS :: { [string]: any }
	local gunStats = if gunName and statsByName[gunName] then statsByName[gunName] else nil
	local amount: number = if gunStats and type(gunStats.damage) == "number" then gunStats.damage else Config.GUN_DAMAGE
	local knockbackForce: number = if gunStats and type(gunStats.knockbackForce) == "number" then gunStats.knockbackForce else Config.GUN_KNOCKBACK_FORCE

	local healthBefore = humanoid.Health
	local rootPart = zombieModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	local deathPosition = if rootPart then rootPart.Position else zombieModel:GetPivot().Position

	if isHeadshot then amount = math.floor(amount * (Config.HEADSHOT_MULTIPLIER :: number)) end

	humanoid:TakeDamage(amount)
	applyKnockback(zombieModel, knockbackForce, shooterPos)
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
