--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local ProfileService = require(ReplicatedStorage.Shared.ProfileService)
local LoadoutGrantModule = require(script.Parent.modules.wave.LoadoutGrantModule)

local TAG = "RNGService"
local RNGService = Framework.CreateService({ Name = TAG })

local _rngActivateRemote: RemoteEvent
local _rngUnlockedListRemote: RemoteEvent
local _rngRequestGiveRemote: RemoteEvent
local _rngTopupRemote: RemoteEvent
local _playerLocks: { [number]: boolean } = {}
local _lastActivateTime: { [number]: number } = {}

local function getPlayerUnlockedList(player: Player)
    local unlocked: { string } = {}
    -- Iterate over configured guns and check profile unlocks
    local gunStats = Config.GUN_STATS :: { [string]: any }
    for gunName, _ in pairs(gunStats) do
        if ProfileService.isWeaponUnlocked(player, gunName) then
            table.insert(unlocked, gunName)
        end
    end
    -- If the profile reports no unlocked weapons, fall back to the player's
    -- currently-owned weapons (Backpack/Character). This lets RNG work
    -- for players who have tools but no unlock records yet.
    if #unlocked == 0 then
        local seen = {}
        for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if item:IsA("Tool") and gunStats[item.Name] and not seen[item.Name] then
                        table.insert(unlocked, item.Name)
                        seen[item.Name] = true
                    end
                end
            end
        end
        if #unlocked > 0 then
            Logger.info(TAG, "No unlocked records; using player's current weapons as fallback (count=%d) for %s", #unlocked, player.Name)
        end
    end

    return unlocked
end

function RNGService:Init()
    _rngActivateRemote = Framework.CreateRemote(RemoteNames.RNG_ACTIVATE)
    _rngUnlockedListRemote = Framework.CreateRemote(RemoteNames.RNG_UNLOCKED_LIST)
    _rngRequestGiveRemote = Framework.CreateRemote(RemoteNames.RNG_REQUEST_GIVE)
    _rngTopupRemote = Framework.CreateRemote(RemoteNames.RNG_TOPUP_AMMO)
end

function RNGService:Start()
    _rngActivateRemote.OnServerEvent:Connect(function(player: Player)
        local uid = player and player.UserId or 0
        local now = tick()
        local last = _lastActivateTime[uid]
        if last and now - last < 0.5 then
            Logger.info(TAG, "Ignoring duplicate RNG_ACTIVATE from %s (cooldown)", player.Name)
            return
        end
        _lastActivateTime[uid] = now
        Logger.info(TAG, "RNG_ACTIVATE received from %s", player.Name)
        -- Find the RNG BLOCK in workspace and destroy it (first match)
        local rngPart = workspace:FindFirstChild("RNG BLOCK", true)
        if rngPart then
            rngPart:Destroy()
            Logger.info(TAG, "Destroyed RNG BLOCK for %s", player.Name)
        else
            Logger.info(TAG, "No RNG BLOCK found to destroy for %s", player.Name)
        end

        local unlocked = getPlayerUnlockedList(player)
        Logger.info(TAG, "Sending unlocked list (count=%d) to %s", #unlocked, player.Name)
        _rngUnlockedListRemote:FireClient(player, unlocked)
    end)

    _rngRequestGiveRemote.OnServerEvent:Connect(function(player: Player, weaponName: string, slotIndex: number, toRemoveName: string?)
        if type(weaponName) ~= "string" then return end
        local uid = player and player.UserId or 0
        if _playerLocks[uid] then
            Logger.info(TAG, "Rejecting RNG_REQUEST_GIVE for %s — swap already in progress", player.Name)
            return
        end
        _playerLocks[uid] = true
        local function unlock()
            _playerLocks[uid] = nil
        end
        local ok, err = pcall(function()
        -- Validate weapon exists
        if not Config.GUN_STATS[weaponName] then return end

        -- Build server-side view of current tools: equipped (Character) and Backpack list
        local currentSet: { [string]: boolean } = {}
        local equippedName: string? = nil
        local backpackTools: { string } = {}
        local character = player.Character
        if character then
            for _, item in ipairs(character:GetChildren()) do
                if item:IsA("Tool") then
                    equippedName = item.Name
                    currentSet[item.Name] = true
                    break
                end
            end
        end
        local backpack = player:FindFirstChildOfClass("Backpack")
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") then
                    table.insert(backpackTools, item.Name)
                    currentSet[item.Name] = true
                end
            end
        end

        Logger.info(TAG, "Server current tools for %s — equipped=%s backpack=%s", player.Name, tostring(equippedName), table.concat(backpackTools, ", "))

        -- Validate player unlocked it OR it's present in their current tools (fallback)
        if not ProfileService.isWeaponUnlocked(player, weaponName) and not currentSet[weaponName] then
            Logger.warn(TAG, "Rejecting RNG grant of %s for %s — not unlocked nor owned.", weaponName, player.Name)
            return
        end

        -- If the rolled weapon is already the player's equipped tool, top up ammo
        if equippedName and equippedName == weaponName then
            local stats = Config.GUN_STATS[weaponName]
            if stats then
                Logger.info(TAG, "Rolled weapon matches equipped (%s) for %s — topping up ammo.", weaponName, player.Name)
                _rngTopupRemote:FireClient(player, weaponName, stats.magSize, stats.max_ammo)
                return
            end
        end

        -- Optionally remove the weapon in the chosen slot (if any). Prefer
        -- the explicit `toRemoveName` sent by the client; otherwise fall back
        -- to the deterministic `current` ordering.
        local function removeGunFromPlayer(playerLocal: Player, gunName: string)
            if type(gunName) ~= "string" or gunName == "" then return false end
            for _, container in ipairs({ playerLocal:FindFirstChildOfClass("Backpack"), playerLocal.Character }) do
                if container then
                    local item = container:FindFirstChild(gunName)
                    if item and item:IsA("Tool") then
                        item:Destroy()
                        Logger.info(TAG, "Removed %s from %s as part of RNG swap.", gunName, playerLocal.Name)
                        return true
                    end
                end
            end
            return false
        end

        if slotIndex == 1 or slotIndex == 2 then
            -- Prefer explicit client-sent name if provided and valid
            local removed = false
            if type(toRemoveName) == "string" and toRemoveName ~= "" then
                Logger.info(TAG, "Client requested removal name: %s", toRemoveName)
                removed = removeGunFromPlayer(player, toRemoveName)
                if not removed then
                    Logger.info(TAG, "Requested removal '%s' not found; falling back to slot mapping.", toRemoveName)
                end
            end

            if not removed then
                local chosen: string? = nil
                if slotIndex == 1 then
                    -- Slot 1: prefer equipped tool
                    if equippedName then chosen = equippedName end
                    if not chosen and #backpackTools > 0 then chosen = backpackTools[1] end
                else
                    -- Slot 2: prefer first backpack tool that isn't the equipped tool
                    if #backpackTools > 0 then
                        if backpackTools[1] ~= equippedName then
                            chosen = backpackTools[1]
                        elseif #backpackTools >= 2 then
                            chosen = backpackTools[2]
                        end
                    end
                end
                if chosen then
                    Logger.info(TAG, "Server-chosen removal for slot %d: %s", slotIndex, chosen)
                    removeGunFromPlayer(player, chosen)
                else
                    Logger.info(TAG, "No tool found for removal for slot %d for %s", slotIndex, player.Name)
                end
            end
        end

        -- Grant the selected weapon (remove happens before grant)
        local granted = LoadoutGrantModule.grant(player, { weaponName }, function(msg: string, ...: any)
            Logger.warn(TAG, msg, ...)
        end)

        -- If we granted a tool, attempt to auto-equip it so the player sees it in the expected slot.
        if granted and granted > 0 then
            task.wait(0.05)
            local backpack = player:FindFirstChildOfClass("Backpack")
            local character = player.Character
            local toolInstance: Instance? = nil
            if backpack then
                toolInstance = backpack:FindFirstChild(weaponName)
            end
            if (not toolInstance) and character then
                toolInstance = character:FindFirstChild(weaponName)
            end
            if toolInstance and character then
                local humanoid = character:FindFirstChildWhichIsA("Humanoid")
                if humanoid then
                    -- This will move the tool into the character and set it as equipped
                    humanoid:EquipTool(toolInstance :: Tool)
                    Logger.info(TAG, "Equipped %s for %s after RNG grant.", weaponName, player.Name)
                else
                    -- As a fallback, parent tool to Character to encourage equip
                    toolInstance.Parent = character
                    Logger.info(TAG, "Moved %s to Character for %s to equip.", weaponName, player.Name)
                end
            else
                Logger.info(TAG, "Could not find granted tool instance for %s after grant to %s.", weaponName, player.Name)
            end
        end
        end)
        if not ok then
            Logger.warn(TAG, "Error handling RNG_REQUEST_GIVE for %s: %s", player.Name, tostring(err))
        end
        unlock()
    end)
end

return RNGService
