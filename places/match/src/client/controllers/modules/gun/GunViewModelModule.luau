--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- RunService not used directly; scheduler handles per-frame loop

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RenderScheduler = require(Shared:WaitForChild("RenderScheduler"))
local Config = require(Shared.Config)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Viewmodel lag configuration (first-order system on rotation)
local BASE_VIEWMODEL_LAG_RESPONSIVENESS = Config.VIEWMODEL_LAG_RESPONSIVENESS or 10 -- base responsiveness
local VIEWMODEL_LAG_RESPONSIVENESS_MULTIPLIER = Config.VIEWMODEL_LAG_RESPONSIVENESS_MULTIPLIER or 3 -- 2-3x for a tighter feel
local VIEWMODEL_LAG_STIFFNESS_SCALE = Config.VIEWMODEL_LAG_STIFFNESS_SCALE or .5 -- user requested: cut stiffness in half
local VIEWMODEL_LAG_RESPONSIVENESS = BASE_VIEWMODEL_LAG_RESPONSIVENESS * VIEWMODEL_LAG_RESPONSIVENESS_MULTIPLIER * VIEWMODEL_LAG_STIFFNESS_SCALE
local VIEWMODEL_LAG_MAX_ANGLE_DEGREES = Config.VIEWMODEL_LAG_MAX_ANGLE_DEGREES or 20 -- maximum angular offset from camera (degrees)
-- Input smoothing (smooth raw camera/mouse CFrame before feeding spring)
local VIEWMODEL_INPUT_SMOOTH_ENABLED = true
-- Double the apparent smoothing: lower responsiveness = smoother (slower to track).
local VIEWMODEL_INPUT_SMOOTH_RESPONSIVENESS = (Config.VIEWMODEL_INPUT_SMOOTH_RESPONSIVENESS or 30) * 2 -- doubled smoothing

local ViewModels = ReplicatedStorage:WaitForChild("ViewModels")

local activeViewmodel: Model? = nil
local renderTaskId: string? = nil
local currentTool: Tool? = nil
local currentTemplate: Model? = nil
local cameraModeConn: RBXScriptConnection? = nil
local cameraCFrameConn: RBXScriptConnection? = nil


-- Helper: sanitize parts on spawn
local function sanitizeViewmodelParts(model: Model)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CastShadow = false
            part.CanCollide = false
            part.LocalTransparencyModifier = 0
            part.CanQuery = false
        end
    end
end

-- Helper: initialize smoothed state
local function initSmoothedState()
    local smoothedCamCFrame = camera and camera.CFrame or CFrame.new()
    local smoothedLook = smoothedCamCFrame.LookVector.Unit or Vector3.new(0,0,-1)
    local smoothedLookVel = Vector3.new(0, 0, 0)
    return smoothedCamCFrame, smoothedLook, smoothedLookVel
end

-- Helper: smooth camera input orientation but keep position immediate
local function updateSmoothedCamCFrame(smoothedCamCFrame: CFrame, dt: number)
    if VIEWMODEL_INPUT_SMOOTH_ENABLED then
        local kInput = math.max(0.0001, VIEWMODEL_INPUT_SMOOTH_RESPONSIVENESS)
        local alphaInput = 1 - math.exp(-kInput * dt)
        smoothedCamCFrame = smoothedCamCFrame:Lerp(camera.CFrame, alphaInput)
        -- Keep the camera position immediate to remove translation lag
        smoothedCamCFrame = CFrame.new(camera.CFrame.Position, camera.CFrame.Position + smoothedCamCFrame.LookVector)
    else
        smoothedCamCFrame = camera.CFrame
    end
    return smoothedCamCFrame
end

-- Helper: compute critically-damped look smoothing and clamp angle
local function computeSmoothedLook(dt: number, camCFrame: CFrame, smoothedLook: Vector3, smoothedLookVel: Vector3)
    local targetLook = camCFrame.LookVector
    if targetLook.Magnitude < 1e-4 then targetLook = Vector3.new(0,0,-1) end
    targetLook = targetLook.Unit

    local w = math.max(0.0001, VIEWMODEL_LAG_RESPONSIVENESS)
    local accel = (targetLook - smoothedLook) * (w * w) - smoothedLookVel * (2 * w)
    smoothedLookVel = smoothedLookVel + accel * dt
    smoothedLook = smoothedLook + smoothedLookVel * dt

    if smoothedLook.Magnitude < 1e-4 then
        smoothedLook = targetLook
        smoothedLookVel = Vector3.new(0, 0, 0)
    else
        smoothedLook = smoothedLook.Unit
    end

    local dot = math.clamp(targetLook:Dot(smoothedLook), -1, 1)
    local angle = math.acos(dot)
    local maxRad = math.rad(math.max(0, VIEWMODEL_LAG_MAX_ANGLE_DEGREES))
    if angle > maxRad and angle > 1e-6 then
        local t = maxRad / angle
        smoothedLook = targetLook:Lerp(smoothedLook, t).Unit
    end

    return smoothedLook, smoothedLookVel
end

-- Helper: apply final viewmodel CFrame using smoothed look and offset
local function applyViewmodelTransform(camCFrame: CFrame, smoothedLook: Vector3, viewmodelOffset: CFrame)
    local smoothedCamCFrame = CFrame.lookAt(camCFrame.Position, camCFrame.Position + smoothedLook, Vector3.new(0,1,0))
    if activeViewmodel and activeViewmodel.PrimaryPart then
        activeViewmodel:SetPrimaryPartCFrame(smoothedCamCFrame * viewmodelOffset:Inverse())
    end
end


local function setWorldToolVisible(visible: boolean)
    local modifier = visible and 0 or 1
    if not currentTool then return end
    for _, descendant in ipairs(currentTool:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.LocalTransparencyModifier = modifier
        end
    end
end

local function destroyActiveViewmodel()
    if renderTaskId then
        RenderScheduler.unregister(renderTaskId)
        renderTaskId = nil
    end
    if activeViewmodel then
        activeViewmodel:Destroy()
        activeViewmodel = nil
    end
end

local function mountViewmodel(template: Model)
    if not template then return end
    destroyActiveViewmodel()
    activeViewmodel = template:Clone()
    activeViewmodel.Archivable = true

    sanitizeViewmodelParts(activeViewmodel)
    activeViewmodel.Parent = camera

    -- Prefer a PrimaryPart for robust model transforms
    local root = activeViewmodel:FindFirstChild("HumanoidRootPart")
    if root and activeViewmodel.PrimaryPart == nil then
        activeViewmodel.PrimaryPart = root
    end

    -- Immediately hide world tool and real arms while viewmodel is mounted
    setWorldToolVisible(false)

    -- Initialize smoothed camera CFrame and look vector + velocity for 2nd-order spring
    local smoothedCamCFrame, smoothedLook, smoothedLookVel = initSmoothedState()

    renderTaskId = RenderScheduler.register("viewmodel_" .. (activeViewmodel and activeViewmodel.Name or "vm"), function(dt)
        if not activeViewmodel or not activeViewmodel.Parent then
            if renderTaskId then
                RenderScheduler.unregister(renderTaskId)
                renderTaskId = nil
            end
            return
        end

        local rootPart = activeViewmodel:FindFirstChild("HumanoidRootPart")
        local fakeCam = activeViewmodel:FindFirstChild("FakeCamera")
        if rootPart and fakeCam and activeViewmodel.PrimaryPart then
            local viewmodelOffset = rootPart.CFrame:ToObjectSpace(fakeCam.CFrame)
            smoothedCamCFrame = updateSmoothedCamCFrame(smoothedCamCFrame, dt)
            local camCFrame = smoothedCamCFrame
            smoothedLook, smoothedLookVel = computeSmoothedLook(dt, camCFrame, smoothedLook, smoothedLookVel)
            applyViewmodelTransform(camCFrame, smoothedLook, viewmodelOffset)
            setWorldToolVisible(false)
        end
    end)
end

local function isFirstPerson(): boolean
    if not player or not player.Character then return false end
    local root = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return false end
    local dist = (camera.CFrame.Position - root.Position).Magnitude
    -- When camera is inside the head/root, consider it first-person. Tweak threshold if needed.
    return dist < 2
end

local Module = {}

function Module.getActiveMuzzleForTool(): BasePart?
    if not activeViewmodel then
        return nil
    end
    local weaponModel = activeViewmodel:FindFirstChild("WeaponModel", true)
    local muzzle: Instance? = weaponModel and weaponModel:FindFirstChild("Muzzle", true) or activeViewmodel:FindFirstChild("Muzzle", true)
    if muzzle and muzzle:IsA("BasePart") then
        return muzzle :: BasePart
    end
    return nil
end

local function updateViewmodelVisibility()
    if not currentTool then
        destroyActiveViewmodel()
        return
    end

    -- If player is in first-person, mount the viewmodel; otherwise show world tool
    if isFirstPerson() then
        if currentTemplate and currentTemplate:IsA("Model") then
            if not activeViewmodel then
                mountViewmodel(currentTemplate)
            end
        end
    else
        if activeViewmodel then
            destroyActiveViewmodel()
        end
        setWorldToolVisible(true)
    end
end

function Module.onGunEquipped(tool: Tool)
    if not tool then return end
    currentTool = tool

    -- Find a ViewModel in ReplicatedStorage matching the tool name
    local template: Model? = nil
    if ViewModels then
        template = ViewModels:FindFirstChild(tool.Name)
    end

    currentTemplate = (template and template:IsA("Model")) and template or nil

    -- Listen for CameraMode changes so we can switch between models live
    if cameraModeConn then
        cameraModeConn:Disconnect()
        cameraModeConn = nil
    end
    if player then
        cameraModeConn = player:GetPropertyChangedSignal("CameraMode"):Connect(updateViewmodelVisibility)
    end
    -- Also listen for camera movement (CFrame) changes to detect first-person toggles
    if cameraCFrameConn then
        cameraCFrameConn:Disconnect()
        cameraCFrameConn = nil
    end
    if camera then
        cameraCFrameConn = camera:GetPropertyChangedSignal("CFrame"):Connect(updateViewmodelVisibility)
    end

    -- Initial visibility update (mount viewmodel if already in first person)
    updateViewmodelVisibility()
end

function Module.onGunUnequipped()
    currentTool = nil
    currentTemplate = nil
    if cameraModeConn then
        cameraModeConn:Disconnect()
        cameraModeConn = nil
    end
    destroyActiveViewmodel()
    setWorldToolVisible(true)
end

return Module