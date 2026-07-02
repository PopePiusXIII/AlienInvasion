--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local InventoryController = require(script.Parent.InventoryController)

local TAG = "RNGController"
local RNGController = Framework.CreateController({ Name = TAG })

local _localPlayer: Player
local _rngActivateRemote: RemoteEvent
local _rngUnlockedListRemote: RemoteEvent
local _rngRequestGiveRemote: RemoteEvent

local _gui: ScreenGui?
local _promptFrame: Frame?
local _selectedLabel: TextLabel?
local _state = {
    visible = false,
    unlocked = {},
    selected = nil :: string?
}
local _attachedRngParts: { [Instance]: RBXScriptConnection } = {}

local function buildGui()
    _gui = Instance.new("ScreenGui")
    _gui.Name = "RNGGui"
    _gui.ResetOnSpawn = false
    _gui.Parent = _localPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 80)
    frame.Position = UDim2.new(0.5, -110, 0.1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = _gui
    _promptFrame = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,1,0)
    label.Position = UDim2.new(0,0,0,0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 18
    label.Text = "Press F to roll"
    label.Parent = frame

    local sel = Instance.new("TextLabel")
    sel.Size = UDim2.new(1,0,0,30)
    sel.Position = UDim2.new(0,0,1,4)
    sel.BackgroundTransparency = 0
    sel.BackgroundColor3 = Color3.fromRGB(20,20,20)
    sel.TextColor3 = Color3.new(1,1,1)
    sel.Font = Enum.Font.GothamBold
    sel.TextSize = 16
    sel.Text = ""
    sel.Parent = frame
    sel.Visible = false
    _selectedLabel = sel
end

local function showPrompt()
    if not _promptFrame then return end
    _promptFrame.Visible = true
    _state.visible = true
end

local function hidePrompt()
    if _promptFrame then _promptFrame.Visible = false end
    if _selectedLabel then _selectedLabel.Text = "" end
    _state.visible = false
    _state.selected = nil
end

local function onSelectWeapon()
    if not _state.unlocked or #_state.unlocked == 0 then
        if _selectedLabel then _selectedLabel.Text = "No unlocked weapons." end
        return
    end
    local rng = Random.new()
    local idx = rng:NextInteger(1, #_state.unlocked)
    local choice = _state.unlocked[idx]
    _state.selected = choice
    Logger.info(TAG, "Rolled RNG choice: %s", choice)

    -- Check if weapon is already in inventory
    local currentWeapons = InventoryController.getWeapons()
    local owned = table.find(currentWeapons, choice) ~= nil
    
    if _selectedLabel then
        if owned then
            _selectedLabel.Text = ("Selected: %s — Max ammo"):format(choice)
            _selectedLabel.Visible = true
            -- If already owned, auto-request top-up (server will handle equipped-case)
            Logger.info(TAG, "Rolled weapon already owned by player: %s — auto-requesting top-up/grant", choice)
            _rngRequestGiveRemote:FireServer(choice, 0, nil)
            -- Hide the prompt shortly after showing the message
            task.delay(1.5, hidePrompt)
        else
            _selectedLabel.Text = ("Selected: %s — Press F/G to take, X to skip"):format(choice)
            _selectedLabel.Visible = true
        end
    end
end

function RNGController:Init()
    _localPlayer = Players.LocalPlayer
end

function RNGController:Start()
    _rngActivateRemote = Framework.GetRemote(RemoteNames.RNG_ACTIVATE)
    _rngUnlockedListRemote = Framework.GetRemote(RemoteNames.RNG_UNLOCKED_LIST)
    _rngRequestGiveRemote = Framework.GetRemote(RemoteNames.RNG_REQUEST_GIVE)

        buildGui()
    -- Listen for unlocked list from server
    _rngUnlockedListRemote.OnClientEvent:Connect(function(unlocked: { string })
        _state.unlocked = unlocked or {}
        Logger.info(TAG, "Received unlocked list (count=%d)", #_state.unlocked)
        if #_state.unlocked > 0 then
            Logger.info(TAG, "Unlocked list contents: %s", table.concat(_state.unlocked, ", "))
        end
        showPrompt()
    end)

    -- Attach handlers to RNG BLOCK parts (existing and future spawns)
    local function handleRngPart(part: BasePart)
        if not part or _attachedRngParts[part] then return end
        local conn = part.Touched:Connect(function(hit)
            local char = _localPlayer.Character
            if not char then return end
            if hit and hit:IsDescendantOf(char) then
                Logger.info(TAG, "Touched RNG BLOCK — firing activate remote")
                _rngActivateRemote:FireServer()
            end
        end)
        _attachedRngParts[part] = conn
    end

    -- Attach to existing RNG BLOCKs
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "RNG BLOCK" then
            if obj:IsA("BasePart") then
                handleRngPart(obj :: BasePart)
            elseif obj:IsA("Model") then
                local anyPart = obj:FindFirstChildWhichIsA("BasePart", true)
                if anyPart then handleRngPart(anyPart :: BasePart) end
            end
        end
    end

    -- Listen for future RNG BLOCK spawns
    workspace.DescendantAdded:Connect(function(desc)
        if desc.Name == "RNG BLOCK" then
            if desc:IsA("BasePart") then
                handleRngPart(desc :: BasePart)
            elseif desc:IsA("Model") then
                local anyPart = desc:FindFirstChildWhichIsA("BasePart", true)
                if anyPart then handleRngPart(anyPart :: BasePart) end
            end
        end
    end)

    -- Input handling
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not _state.visible then return end
        if input.KeyCode == Enum.KeyCode.F then
            if _state.selected then
                -- If already selected, treat F as slot1 selection
                local currentWeapons = InventoryController.getWeapons()
                local toRemove: string? = nil
                if #currentWeapons >= 1 then
                    toRemove = currentWeapons[1]
                end
                
                Logger.info(TAG, "Client current inventory — weapons=%s", table.concat(currentWeapons, ", "))
                Logger.info(TAG, "Requesting give: %s (slot=1) remove=%s", _state.selected, tostring(toRemove))
                _rngRequestGiveRemote:FireServer(_state.selected, 1, toRemove)
                hidePrompt()
            else
                Logger.info(TAG, "F pressed while prompt visible")
                onSelectWeapon()
            end
        elseif input.KeyCode == Enum.KeyCode.G then
            if _state.selected then
                local currentWeapons = InventoryController.getWeapons()
                local toRemove: string? = nil
                if #currentWeapons >= 2 then
                    toRemove = currentWeapons[2]
                elseif #currentWeapons >= 1 then
                    toRemove = currentWeapons[1]
                end

                Logger.info(TAG, "Client current inventory — weapons=%s", table.concat(currentWeapons, ", "))
                Logger.info(TAG, "Requesting give: %s (slot=2) remove=%s", _state.selected, tostring(toRemove))
                _rngRequestGiveRemote:FireServer(_state.selected, 2, toRemove)
                hidePrompt()
            end
        elseif input.KeyCode == Enum.KeyCode.X then
            hidePrompt()
        end
    end)
end

return RNGController