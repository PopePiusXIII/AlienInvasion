--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ViewModels = ReplicatedStorage:WaitForChild("ViewModels")

local activeViewmodel: Model? = nil
local renderConnection: RBXScriptConnection? = nil
local currentTool: Tool? = nil
local currentTemplate: Model? = nil
local cameraModeConn: RBXScriptConnection? = nil
local cameraCFrameConn: RBXScriptConnection? = nil


local function setWorldToolVisible(visible: boolean)
    local modifier = visible and 0 or 1
    modifier = 0
    if not currentTool then return end
    for _, descendant in ipairs(currentTool:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.LocalTransparencyModifier = modifier
        end
    end
end

local function destroyActiveViewmodel()
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
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

    for _, part in ipairs(activeViewmodel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CastShadow = false
            part.CanCollide = false
            part.LocalTransparencyModifier = 0
            part.CanQuery = false
        end
    end

    activeViewmodel.Parent = camera

    -- Prefer a PrimaryPart for robust model transforms
    local root = activeViewmodel:FindFirstChild("HumanoidRootPart")
    if root and activeViewmodel.PrimaryPart == nil then
        activeViewmodel.PrimaryPart = root
    end

    -- Debug: compare muzzle offsets in template vs clone when verbose
    if Config and Config.DEBUG_VERBOSE then
        local function debugLogMuzzleState(model: Model, label: string)
            local m = model:FindFirstChild("Muzzle", true)
            local r = model:FindFirstChild("HumanoidRootPart")
            if m and r and m:IsA("BasePart") and r:IsA("BasePart") then
                local rel = r.CFrame:ToObjectSpace(m.CFrame)
                Logger.info("GunViewModelModule", label .. " muzzle rel to root: " .. tostring(rel))
            else
                Logger.info("GunViewModelModule", label .. " muzzle or root missing for debug")
            end
        end
        -- If we have a template (passed into mountViewmodel), log its muzzle too if possible
        -- Note: currentTemplate is set elsewhere; just log the clone state here
        debugLogMuzzleState(activeViewmodel, "activeViewmodel (cloned)")
    end

    -- Immediately hide world tool and real arms while viewmodel is mounted
    setWorldToolVisible(false)

    renderConnection = RunService.RenderStepped:Connect(function()
        if not activeViewmodel or not activeViewmodel.Parent then
            if renderConnection then
                renderConnection:Disconnect()
                renderConnection = nil
            end
            return
        end

        local rootPart = activeViewmodel:FindFirstChild("HumanoidRootPart")
        local fakeCam = activeViewmodel:FindFirstChild("FakeCamera")
        if rootPart and fakeCam and activeViewmodel.PrimaryPart then
            local viewmodelOffset = rootPart.CFrame:ToObjectSpace(fakeCam.CFrame)
            -- Use SetPrimaryPartCFrame for more robust model transforms
            activeViewmodel:SetPrimaryPartCFrame(camera.CFrame * viewmodelOffset:Inverse())
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

function Module.getActiveMuzzleForTool(toolName: string): BasePart?
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