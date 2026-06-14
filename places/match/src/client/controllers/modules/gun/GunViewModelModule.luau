--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ViewModels = ReplicatedStorage:WaitForChild("ViewModels")

local activeViewmodel: Model? = nil
local renderConnection: RBXScriptConnection? = nil
local currentTool: Tool? = nil
local currentTemplate: Model? = nil
local cameraModeConn: RBXScriptConnection? = nil
local cameraCFrameConn: RBXScriptConnection? = nil

local function setRealArmsVisible(visible: boolean)
    local character = player and player.Character
    if not character then return end
    local modifier = visible and 0 or 1
    for _, limb in ipairs(character:GetChildren()) do
        if limb:IsA("BasePart") and (string.find(limb.Name, "Arm") or string.find(limb.Name, "Hand")) then
            limb.LocalTransparencyModifier = modifier
        end
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
        end
    end

    activeViewmodel.Parent = camera

    -- Immediately hide world tool and real arms while viewmodel is mounted
    setRealArmsVisible(false)
    setWorldToolVisible(false)

    renderConnection = RunService.RenderStepped:Connect(function()
        if not activeViewmodel or not activeViewmodel.Parent then
            if renderConnection then
                renderConnection:Disconnect()
                renderConnection = nil
            end
            return
        end

        local root = activeViewmodel:FindFirstChild("HumanoidRootPart")
        local fakeCam = activeViewmodel:FindFirstChild("FakeCamera")
        if root and fakeCam then
            local viewmodelOffset = root.CFrame:ToObjectSpace(fakeCam.CFrame)
            root.CFrame = camera.CFrame * viewmodelOffset:Inverse()
            setRealArmsVisible(false)
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
    return dist < 0.75
end

local Module = {}

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
        setRealArmsVisible(true)
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
    -- Fallback: try lowercased name
    if not template and ViewModels then
        template = ViewModels:FindFirstChild(string.lower(tool.Name))
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
    setRealArmsVisible(true)
    setWorldToolVisible(true)
end

return Module