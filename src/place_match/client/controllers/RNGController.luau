--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local InventoryController = require(script.Parent.InventoryController)
local RngHud = require(ReplicatedStorage.Shared.ui.RngHud)

local TAG = "RNGController"
local RNGController = Framework.CreateController({ Name = TAG })

local _localPlayer: Player
local _rngActivateRemote: RemoteFunction
local _rngRequestGiveRemote: RemoteEvent

local _gui: ScreenGui = RngHud
local _promptFrame: Frame?
local _selectedLabel: TextLabel?
local _state = {
    visible = false,
    unlocked = {},
    selected = nil :: string?
}
local _attachedRngParts: { [Instance]: RBXScriptConnection } = {}

local function buildGui()
    _gui.Parent = _localPlayer:WaitForChild("PlayerGui")
    _gui.Enabled = false
    _promptFrame = _gui:FindFirstChild("Frame") :: Frame?
    _selectedLabel = _gui:FindFirstChild("TextLabel", true) :: TextLabel?
end

local function showPrompt()
    _gui.Enabled = true
    if _promptFrame then _promptFrame.Visible = true end
    _state.visible = true
end

local function hidePrompt()
    _gui.Enabled = false
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
    local owned = InventoryController.hasWeapon(choice)
    
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
    _rngActivateRemote = Framework.GetRemoteFunction(RemoteNames.RNG_ACTIVATE)
    _rngRequestGiveRemote = Framework.GetRemote(RemoteNames.RNG_REQUEST_GIVE)

    buildGui()

    -- Read unlocked weapons from Player attribute (set by RNGService on server)
    local function readUnlockedList(): { string }
        local raw = _localPlayer:GetAttribute("RngUnlockedWeapons")
        if not raw or type(raw) ~= "string" or raw == "" then return {} end
        return string.split(raw, ",")
    end

    -- Initial read
    _state.unlocked = readUnlockedList()
    Logger.info(TAG, "Initial unlocked list (count=%d)", #_state.unlocked)

    -- Listen for changes (e.g. after profile loads late)
    _localPlayer:GetAttributeChangedSignal("RngUnlockedWeapons"):Connect(function()
        _state.unlocked = readUnlockedList()
        Logger.info(TAG, "Unlocked list updated (count=%d)", #_state.unlocked)
    end)

    -- Attach handlers to RNG BLOCK parts (existing and future spawns)
    local function handleRngPart(part: any)
        if not part:IsA("BasePart") then return end
        if _attachedRngParts[part] then return end
        local conn = part.Touched:Connect(function(hit)
            local char = _localPlayer.Character
            if not char then return end
            if hit and hit:IsDescendantOf(char) then
                Logger.info(TAG, "Touched RNG BLOCK — showing prompt + firing activate remote")
                local items = _rngActivateRemote:InvokeServer()
                showPrompt(items)
            end
        end)
        _attachedRngParts[part] = conn
    end

    -- Attach to existing RNG BLOCKs
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name ~= "RNG BLOCK" then continue end
        if obj:IsA("BasePart") then
            handleRngPart(obj)
        elseif obj:IsA("Model") then
            local anyPart = obj:FindFirstChildWhichIsA("BasePart", true)
            if anyPart then handleRngPart(anyPart) end
        end
    end

    -- Listen for future RNG BLOCK spawns
    workspace.DescendantAdded:Connect(function(desc)
        if desc.Name ~= "RNG BLOCK" then return end
        if desc:IsA("BasePart") then
            handleRngPart(desc)
        elseif desc:IsA("Model") then
            local anyPart = desc:FindFirstChildWhichIsA("BasePart", true)
            if anyPart then handleRngPart(anyPart) end
        end
    end)

    -- Input handling
    -- UserInputService.InputBegan:Connect(function(input, gameProcessed)
    --     if gameProcessed then return end
    --     if not _state.visible then return end
    --     if input.KeyCode == Enum.KeyCode.F then
    --         if _state.selected then
    --             -- If already selected, treat F as slot1 selection
    --             local toRemove: string? = nil

    --             Logger.info(TAG, "Client current inventory — weapons=%s", table.concat(InventoryController.getWeapons(), ", "))
    --             Logger.info(TAG, "Requesting give: %s (slot=1) remove=%s", _state.selected, tostring(toRemove))
    --             _rngRequestGiveRemote:FireServer(_state.selected, 1, toRemove)
    --             hidePrompt()
    --         else
    --             Logger.info(TAG, "F pressed while prompt visible")
    --             onSelectWeapon()
    --         end
    --     elseif input.KeyCode == Enum.KeyCode.G then
    --         if _state.selected then
    --             local toRemove: string? = nil


    --             Logger.info(TAG, "Client current inventory — weapons=%s", table.concat(InventoryController.getWeapons(), ", "))
    --             Logger.info(TAG, "Requesting give: %s (slot=2) remove=%s", _state.selected, tostring(toRemove))
    --             _rngRequestGiveRemote:FireServer(_state.selected, 2, toRemove)
    --             hidePrompt()
    --         end
    --     elseif input.KeyCode == Enum.KeyCode.X then
    --         hidePrompt()
    --     end
    -- end)
end

return RNGController
