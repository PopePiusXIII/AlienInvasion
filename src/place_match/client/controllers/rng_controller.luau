-- --!strict
-- local Players = game:GetService("Players")
-- local replicated_storage = game:GetService("ReplicatedStorage")
-- local UserInputService = game:GetService("UserInputService")

-- local Framework = require(replicated_storage.common.shared.framework)
-- local Logger    = require(replicated_storage.common.shared.logger)
-- local RemoteNames = require(replicated_storage.match.shared.remote_names)
-- local InventoryController = require(replicated_storage.match.client.controllers.inventory_controller)
-- local RngHud = require(replicated_storage.match.ui.rng_hud)

-- local TAG = "RNGController"
-- local RNGController = {}
-- RNGController.Name = TAG

-- local _localPlayer: Player
-- local _rngActivateRemote: RemoteEvent
-- local _rngRequestGiveRemote: RemoteEvent

-- local _gui: ScreenGui = RngHud
-- local _promptFrame: Frame?
-- local _selectedLabel: TextLabel?
-- local _state = {
--     visible = false,
--     unlocked = {},
--     selected = nil :: string?
-- }
-- local _attachedRngParts: { [Instance]: RBXScriptConnection } = {}


-- function RNGController:Init()
--     _localPlayer = Players.LocalPlayer
-- end

-- function RNGController:Start()
--     _rngActivateRemote = Framework.GetRemote(RemoteNames.RNG_ACTIVATE)
--     _rngRequestGiveRemote = Framework.GetRemote(RemoteNames.RNG_REQUEST_GIVE)

--     buildGui()

--     _rngActivateRemote.OnClientEvent:Connect(function()
--         showPrompt()
--     end)

--     -- Read unlocked weapons from Player attribute (set by RNGService on server)
--     local function readUnlockedList(): { string }
--         local raw = _localPlayer:GetAttribute("RngUnlockedWeapons")
--         if not raw or type(raw) ~= "string" or raw == "" then return {} end
--         return string.split(raw, ",")
--     end

--     -- Initial read
--     _state.unlocked = readUnlockedList()
--     Logger.info(TAG, "Initial unlocked list (count=%d)", #_state.unlocked)

--     -- Listen for changes (e.g. after profile loads late)
--     _localPlayer:GetAttributeChangedSignal("RngUnlockedWeapons"):Connect(function()
--         _state.unlocked = readUnlockedList()
--         Logger.info(TAG, "Unlocked list updated (count=%d)", #_state.unlocked)
--     end)

--     -- Attach handlers to RNG BLOCK parts (existing and future spawns)
--     local function handleRngPart(part: any)
--         if not part:IsA("BasePart") then return end
--         if _attachedRngParts[part] then return end
--         local conn = part.Touched:Connect(function(hit)
--             local char = _localPlayer.Character
--             if not char then return end
--             if hit and hit:IsDescendantOf(char) then
--                 Logger.info(TAG, "Touched RNG BLOCK — showing prompt")
--                 showPrompt()
--             end
--         end)
--         _attachedRngParts[part] = conn
--     end

--     -- Attach to existing RNG BLOCKs
--     for _, obj in ipairs(workspace:GetDescendants()) do
--         if obj.Name ~= "RNG BLOCK" then continue end
--         if obj:IsA("BasePart") then
--             handleRngPart(obj)
--         elseif obj:IsA("Model") then
--             local anyPart = obj:FindFirstChildWhichIsA("BasePart", true)
--             if anyPart then handleRngPart(anyPart) end
--         end
--     end

--     -- Listen for future RNG BLOCK spawns
--     workspace.DescendantAdded:Connect(function(desc)
--         if desc.Name ~= "RNG BLOCK" then return end
--         if desc:IsA("BasePart") then
--             handleRngPart(desc)
--         elseif desc:IsA("Model") then
--             local anyPart = desc:FindFirstChildWhichIsA("BasePart", true)
--             if anyPart then handleRngPart(anyPart) end
--         end
--     end)

-- end

-- Framework.CreateController(RNGController)
-- return RNGController
