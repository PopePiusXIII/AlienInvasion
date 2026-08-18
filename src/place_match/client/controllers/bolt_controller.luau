--!strict
-- BoltController (refactored)
-- Responsibilities:
--  - Manage client bolt visuals
--  - Listen for bolt spawn events and animate bolts each frame
--  - Fire claim requests when player collects a bolt

local Players = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")
local RenderScheduler = require(replicated_storage.match.shared.render_scheduler)

local Framework = require(replicated_storage.common.shared.framework)
local Config    = require(replicated_storage.match.shared.configs.economy_config)

local TAG = "BoltController"
local BoltController = {}
BoltController.Name = TAG

local BOLT_LIFETIME = 10

-- Burst / bounce physics constants (lightweight, low-cost per-frame math)
local BURST_SPEED = 12
local BURST_UP_MIN = 6
local BURST_UP_MAX = 10
local GRAVITY = 100
local BOUNCE_DAMPING = 0.3
local HORIZONTAL_DAMPING = 0.7
local MAX_BOUNCES = 5

type ClientBoltState = {
    id: number,
    bolt: Model,
    center: Vector3,
    hoverY: number,
    groundY: number,
    riseElapsed: number,
    velocity: Vector3,
    phase: string,
    bounces: number,
    attractSpeed: number,
    claimed: boolean,
    spawnTime: number,
}

local activeBolts: { ClientBoltState } = {}
local boltTaskId: string? = nil
local silverTemplate: Model
local goldTemplate: Model

local boltSpawnedRemote: RemoteEvent
local claimBoltRemote: RemoteEvent

local localPlayer: Player

local rng = Random.new()

local function moveBolt(bolt: Model, pos: Vector3)
    bolt:PivotTo(CFrame.new(pos))
end

local function claimBolt(state: ClientBoltState)
    if state.claimed then
        return
    end
    state.claimed = true
    if state.bolt.Parent then
        state.bolt:Destroy()
    end
    claimBoltRemote:FireServer(state.id)
end

local function getTemplateForCurrency(currencyName: string): Model
    if currencyName == "Silver" then
        return silverTemplate
    elseif currencyName == "Gold" then
        return goldTemplate
    else
        error(("%s: Unknown currency name '%s' passed to bolt spawner"):format(TAG, tostring(currencyName)))
    end
end

local function prepareBoltModel(boltModel: Model)
    local hasBasePart = false
    for _, desc in ipairs(boltModel:GetDescendants()) do
        if desc:IsA("BasePart") then
            local p = desc :: BasePart
            hasBasePart = true
            p.Anchored = true
            p.CanCollide = false
            p.CanTouch = false
            p.Transparency = 0
        end
    end
    if not hasBasePart then
        error(('%s: Bolt model "%s" contains no BasePart descendants'):format(TAG, boltModel.Name))
    end
end

local function createAndRegisterBolt(id: number, currencyName: string, _amount: number, spawnPosition: Vector3)
    local template = getTemplateForCurrency(currencyName)

    local bolt = template:Clone()
    bolt.Name = currencyName .. "BoltPickup_" .. tostring(id)

    if not bolt:IsA("Model") then
        bolt:Destroy()
        error(('%s: Cloned bolt template "%s" is not a Model'):format(TAG, template.Name))
    end

    local boltModel = bolt :: Model
    prepareBoltModel(boltModel)

    boltModel.Parent = workspace
    boltModel:MoveTo(spawnPosition)

    local cf, _ = boltModel:GetBoundingBox()
    local center = cf.Position

    -- Determine hoverY by raycasting straight down from above the spawn position.
    -- We blacklist zombie models (models with a Humanoid) so the ray won't hit the dying
    -- zombie body and instead returns the world ground under the spawn.
    local rayStart = spawnPosition + Vector3.new(0, 50, 0)
    local rayDir = Vector3.new(0, -500, 0)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local excludedInstances: { Instance } = { boltModel }
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("Model") then
            local hm = inst:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
            if hm then
                table.insert(excludedInstances, inst)
            end
        end
    end
    rp.FilterDescendantsInstances = excludedInstances
    local ray = workspace:Raycast(rayStart, rayDir, rp)
    local groundY: number
    local computedHoverY: number
    if ray and ray.Position then
        groundY = ray.Position.Y
        computedHoverY = groundY + (Config.BOLT_HOVER_HEIGHT :: number)
    else
        boltModel:Destroy()
        error(('%s: Bolt hover raycast missed at %s'):format(TAG, tostring(spawnPosition)))
    end

    local state: ClientBoltState = {
        id = id,
        bolt = boltModel,
        center = center,
        hoverY = computedHoverY,
        groundY = groundY,
        riseElapsed = 0,
        velocity = Vector3.new(0, 0, 0),
        phase = "burst",
        bounces = 0,
        attractSpeed = 0,
        claimed = false,
        spawnTime = tick(),
    }

    table.insert(activeBolts, state)
    if boltTaskId then
        RenderScheduler.setEnabled(boltTaskId, true)
    end
    -- initialize burst velocity: random horizontal direction + upward component
    do
        local angle = rng:NextNumber(0, math.pi * 2)
        local horiz = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local up = rng:NextNumber(BURST_UP_MIN, BURST_UP_MAX)
        state.velocity = horiz * BURST_SPEED + Vector3.new(0, up, 0)
    end
end

-- Named event callback to comply with no-inline-functions rule
local function onBoltSpawned(id: number, currencyName: string, amount: number, spawnPosition: Vector3)
    createAndRegisterBolt(id, currencyName, amount, spawnPosition)
end

local function isExpired(state: ClientBoltState): boolean
    return (tick() - state.spawnTime) >= BOLT_LIFETIME
end

local function purgeBoltAtIndex(index: number)
    local s = activeBolts[index]
    if s.bolt.Parent then
        s.bolt:Destroy()
    end
    activeBolts[index] = activeBolts[#activeBolts]
    activeBolts[#activeBolts] = nil
end

local function processRise(state: ClientBoltState, dt: number, riseDuration: number)
    state.riseElapsed += dt
    local t = math.min(state.riseElapsed / riseDuration, 1)
    local easedY = state.groundY + (state.hoverY - state.groundY) * (1 - (1 - t) ^ 2)
    state.center = Vector3.new(state.center.X, easedY, state.center.Z)
    if t >= 1 then
        state.phase = "hover"
    end
end

local function processBurst(state: ClientBoltState, dt: number)
    -- Integrate velocity with simple gravity
    state.velocity = state.velocity + Vector3.new(0, -GRAVITY * dt, 0)
    state.center = state.center + state.velocity * dt

    -- Ground contact check (use the raycast-determined ground Y)
    if state.center.Y <= state.groundY then
        -- clamp to ground
        state.center = Vector3.new(state.center.X, state.groundY, state.center.Z)

        -- bounce
        state.velocity = Vector3.new(state.velocity.X * HORIZONTAL_DAMPING, -state.velocity.Y * BOUNCE_DAMPING, state.velocity.Z * HORIZONTAL_DAMPING)
        state.bounces += 1

        if state.bounces >= MAX_BOUNCES then
            -- transition to rising/hover phase
            state.phase = "rising"
            state.riseElapsed = 0
        end
    end
end

local function processAttraction(state: ClientBoltState, playerPos: Vector3, dt: number, attractRadius: number, attractAccel: number, collectRadius: number): boolean
    local dx = playerPos.X - state.center.X
    local dy = playerPos.Y - state.center.Y
    local dz = playerPos.Z - state.center.Z
    local mag = math.sqrt(dx * dx + dy * dy + dz * dz)

    if mag <= collectRadius then
        claimBolt(state)
        return true
    end

    if mag <= attractRadius then
        state.attractSpeed = math.min(state.attractSpeed + attractAccel * dt, 40)
        if mag > 0.5 then
            local inv = state.attractSpeed * dt / mag
            state.center = Vector3.new(state.center.X + dx * inv, state.center.Y + dy * inv, state.center.Z + dz * inv)
        end
    else
        state.attractSpeed = 0
    end

    return false
end

local function updateBolts(dt: number)
    if #activeBolts == 0 then
        if boltTaskId then
            RenderScheduler.setEnabled(boltTaskId, false)
        end
        return
    end

    local character = localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local playerPos: Vector3? = rootPart and (rootPart :: BasePart).Position

    local riseDuration = Config.BOLT_RISE_DURATION :: number
    local attractRadius = Config.BOLT_ATTRACT_RADIUS :: number
    local attractAccel = Config.BOLT_ATTRACT_ACCELERATION :: number
    local collectRadius = Config.BOLT_COLLECT_RADIUS :: number

    for i = #activeBolts, 1, -1 do
        local state = activeBolts[i]
        local shouldPurge = state.claimed or not state.bolt.Parent or isExpired(state)

        if not shouldPurge then
            if state.phase == "burst" then
                processBurst(state, dt)
            elseif state.phase == "rising" then
                processRise(state, dt, riseDuration)
            elseif state.phase == "hover" and playerPos then
                shouldPurge = processAttraction(state, playerPos, dt, attractRadius, attractAccel, collectRadius)
            end
        end

        if shouldPurge then
            purgeBoltAtIndex(i)
        else
            moveBolt(state.bolt, state.center)
        end
    end
end

function BoltController:Init()
    localPlayer = Players.LocalPlayer

    local templates = replicated_storage:FindFirstChild("BoltTemplates")
    if not templates then
        error(('%s: Missing BoltTemplates folder in ReplicatedStorage'):format(TAG))
    end

    local silver = templates:FindFirstChild("SilverBolt")
    if not silver or not silver:IsA("Model") then
        error(('%s: SilverBolt template missing or not a Model in BoltTemplates'):format(TAG))
    end
    silverTemplate = silver :: Model

    local gold = templates:FindFirstChild("GoldBolt")
    if not gold or not gold:IsA("Model") then
        error(('%s: GoldBolt template missing or not a Model in BoltTemplates'):format(TAG))
    end
    goldTemplate = gold :: Model
end

function BoltController:Start()
    boltSpawnedRemote = Framework.GetRemote("BoltSpawned")
    claimBoltRemote = Framework.GetRemote("ClaimBolt")

    boltSpawnedRemote.OnClientEvent:Connect(onBoltSpawned)

    boltTaskId = RenderScheduler.register("bolts", updateBolts, { enabled = false })
end

Framework.CreateController(BoltController)
return BoltController
