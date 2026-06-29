--!strict
-- Client-side manager to play zombie animations when available in config.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Configs.ZombieConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)

local TAG = "ZombieAnimationManager"

local ZombieAnimationManager = {}

-- Per-zombie internal state
type ZombieState = {
    model: Model,
    humanoid: Humanoid,
    tracks: { [string]: AnimationTrack },
    conns: { RBXScriptConnection },
}

local _tracked: { [Instance]: ZombieState } = {}

local function getZombieTypeName(model: Model): string
    local attr = model:GetAttribute("ZombieType")
    if attr and type(attr) == "string" and attr ~= "" then
        return attr
    end

    local val = model:FindFirstChild("ZombieType") :: StringValue?
    if val and val:IsA("StringValue") then
        return val.Value
    end

    return Config.ZOMBIE_DEFAULT_TYPE
end

local function safeLoadAnimation(humanoid: Humanoid, id: any)
    if not id then return nil end
    local ok, track = pcall(function()
        local anim = Instance.new("Animation")
        anim.AnimationId = string.format("rbxassetid://%s", tostring(id))
        local t = humanoid:LoadAnimation(anim)
        return t
    end)
    if ok then return track end
    return nil
end

local function setupZombie(model: Model)
    if _tracked[model] then return end
    local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid?
    if not humanoid then
        Logger.warn(TAG, "Zombie %q has no Humanoid; skipping animation setup.", model:GetFullName())
        return
    end

    local typeName = getZombieTypeName(model)
    local typeCfg = Config.ZOMBIE_TYPES[typeName]
    if not typeCfg then
        typeCfg = Config.ZOMBIE_TYPES[Config.ZOMBIE_DEFAULT_TYPE]
    end

    local animations = typeCfg and typeCfg.Animations
    if not animations or next(animations) == nil then
        -- Nothing to do; exit silently as requested.
        return
    end

    -- Ensure Animator exists
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local state: ZombieState = {
        model = model,
        humanoid = humanoid,
        tracks = {},
        conns = {},
    }

    -- Preload tracks for supported actions
    if animations.walk then
        local t = safeLoadAnimation(humanoid, animations.walk)
        if t then t.Looped = true end
        state.tracks.walk = t
    end
    if animations.jump then
        state.tracks.jump = safeLoadAnimation(humanoid, animations.jump)
    end
    if animations.attack then
        state.tracks.attack = safeLoadAnimation(humanoid, animations.attack)
    end

    -- Connect Running for walk detection
    local runningConn = humanoid.Running:Connect(function(speed)
        local walkTrack = state.tracks.walk
        if walkTrack then
            if speed > 1 then
                if not walkTrack.IsPlaying then
                    walkTrack:Play()
                end
            else
                if walkTrack.IsPlaying then
                    walkTrack:Stop()
                end
            end
        end
    end)
    table.insert(state.conns, runningConn)

    -- Connect StateChanged for jump
    local stateConn = humanoid.StateChanged:Connect(function(old, new)
        local jumpTrack = state.tracks.jump
        if jumpTrack and new == Enum.HumanoidStateType.Jumping then
            jumpTrack:Play()
        end
    end)
    table.insert(state.conns, stateConn)

    -- Connect attack BoolValue if present
    local attackVal = model:FindFirstChild("Attacking")
    if attackVal and attackVal:IsA("BoolValue") then
        local attackConn = attackVal.Changed:Connect(function(val)
            if val then
                local aTrack = state.tracks.attack
                if aTrack then
                    aTrack:Play()
                end
            end
        end)
        table.insert(state.conns, attackConn)
    end

    -- Clean up when model removed
    local parentConn = model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            -- disconnect
            for _, c in ipairs(state.conns) do
                pcall(function() c:Disconnect() end)
            end
            _tracked[model] = nil
        end
    end)
    table.insert(state.conns, parentConn)

    _tracked[model] = state
    -- Logger.info(TAG, "Animations set up for zombie %q (type=%s)", model:GetFullName(), tostring(typeName))
end

function ZombieAnimationManager.Start()
    local workspace = game:GetService("Workspace")

    -- Register existing zombies
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "Zombie" and child:IsA("Model") then
            setupZombie(child :: Model)
        end
    end

    -- Watch for future zombies
    workspace.ChildAdded:Connect(function(child)
        if child.Name == "Zombie" and child:IsA("Model") then
            setupZombie(child :: Model)
        end
    end)

    Logger.info(TAG, "ZombieAnimationManager started.")
end

return ZombieAnimationManager
