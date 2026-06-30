--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local Config    = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local ProfileService = require(ReplicatedStorage.Shared.ProfileService)
local LoadoutGrantModule = require(script.Parent.modules.wave.LoadoutGrantModule)
local InventoryService = nil -- Lazy-loaded to avoid circular dependency

local TAG = "RNGService"
local RNGService = Framework.CreateService({ Name = TAG })

local _rngActivateRemote: RemoteEvent
local _rngUnlockedListRemote: RemoteEvent
local _rngRequestGiveRemote: RemoteEvent
local _rngTopupRemote: RemoteEvent
local _playerLocks: { [number]: boolean } = {}
local _lastActivateTime: { [number]: number } = {}

local function getPlayerUnlockedList(player: Player)
    -- Lazy-load InventoryService
    if not InventoryService then
        InventoryService = Framework.GetService("InventoryService")
    end
    
    local unlocked: { string } = {}
    -- Iterate over configured guns and check profile unlocks
    local gunStats = Config.GUN_STATS :: { [string]: any }
    for gunName, _ in pairs(gunStats) do
        if ProfileService.isWeaponUnlocked(player, gunName) then
            table.insert(unlocked, gunName)
        end
    end
    -- If the profile reports no unlocked weapons, fall back to the player's
    -- current inventory weapons.
    if #unlocked == 0 then
        local currentWeapons = InventoryService.getWeapons(player)
        for _, weaponName in ipairs(currentWeapons) do
            if gunStats[weaponName] then
                table.insert(unlocked, weaponName)
            end
        end
        if #unlocked > 0 then
            Logger.info(TAG, "No unlocked records; using player's current inventory as fallback (count=%d) for %s", #unlocked, player.Name)
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
        -- Lazy-load InventoryService
        if not InventoryService then
            InventoryService = Framework.GetService("InventoryService")
        end
        
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

        -- Get current inventory state
        local currentWeapons = InventoryService.getWeapons(player)
        local equippedWeapon = InventoryService.getEquippedWeapon(player)
        local currentSet: { [string]: boolean } = {}
        for _, w in ipairs(currentWeapons) do
            currentSet[w] = true
        end

        Logger.info(TAG, "Server current inventory for %s — weapons=%s, equipped=%s", 
            player.Name, table.concat(currentWeapons, ", "), tostring(equippedWeapon))

        -- Validate player unlocked it OR it's present in their current inventory (fallback)
        if not ProfileService.isWeaponUnlocked(player, weaponName) and not currentSet[weaponName] then
            Logger.warn(TAG, "Rejecting RNG grant of %s for %s — not unlocked nor owned.", weaponName, player.Name)
            return
        end

        -- If the rolled weapon is already the player's equipped weapon, top up ammo
        if equippedWeapon and equippedWeapon == weaponName then
            local stats = Config.GUN_STATS[weaponName]
            if stats then
                Logger.info(TAG, "Rolled weapon matches equipped (%s) for %s — topping up ammo.", weaponName, player.Name)
                _rngTopupRemote:FireClient(player, weaponName, stats.magSize, stats.max_ammo)
                return
            end
        end

        -- Remove weapon from inventory if needed
        if slotIndex >= 1 and slotIndex <= #currentWeapons then
            local toRemove = toRemoveName
            if not toRemove or toRemove == "" then
                -- Fall back to slot-based removal
                toRemove = currentWeapons[slotIndex]
            end
            
            if toRemove and toRemove ~= "" then
                Logger.info(TAG, "Removing weapon %s from slot %d for %s", toRemove, slotIndex, player.Name)
                InventoryService.removeWeapon(player, toRemove)
            end
        end

        -- Grant the selected weapon via inventory system
        local success = InventoryService.addWeapon(player, weaponName)
        if success then
            Logger.info(TAG, "Added %s to inventory for %s via RNG", weaponName, player.Name)
            -- Auto-equip the new weapon
            local newWeapons = InventoryService.getWeapons(player)
            for i, w in ipairs(newWeapons) do
                if w == weaponName then
                    InventoryService.setEquippedSlot(player, i)
                    break
                end
            end
        else
            Logger.warn(TAG, "Failed to add %s to inventory for %s", weaponName, player.Name)
        end
        end)
        if not ok then
            Logger.warn(TAG, "Error handling RNG_REQUEST_GIVE for %s: %s", player.Name, tostring(err))
        end
        unlock()
    end)
end

return RNGService
