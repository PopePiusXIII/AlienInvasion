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
end

function RNGService:Start()
    _rngActivateRemote.OnServerEvent:Connect(function(player: Player)
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

    _rngRequestGiveRemote.OnServerEvent:Connect(function(player: Player, weaponName: string, slotIndex: number)
        if type(weaponName) ~= "string" then return end
        -- Validate weapon exists
        if not Config.GUN_STATS[weaponName] then return end
        -- Validate player unlocked it
        if not ProfileService.isWeaponUnlocked(player, weaponName) then return end

        -- Optionally remove the weapon in the chosen slot (if any)
        local prices = Config.SHOP_GUN_PRICES :: { [string]: number }
        local function removeGunFromPlayer(playerLocal: Player, gunName: string)
            for _, container in ipairs({ playerLocal:FindFirstChildOfClass("Backpack"), playerLocal.Character }) do
                if container then
                    local item = container:FindFirstChild(gunName)
                    if item and item:IsA("Tool") then
                        item:Destroy()
                        return true
                    end
                end
            end
            return false
        end

        -- Find current guns (only those present in GUN_STATS)
        local current: { string } = {}
        for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if item:IsA("Tool") and Config.GUN_STATS[item.Name] then
                        table.insert(current, item.Name)
                    end
                end
            end
        end

        if slotIndex == 1 or slotIndex == 2 then
            local toRemove = current[slotIndex]
            if toRemove then
                removeGunFromPlayer(player, toRemove)
            end
        end

        -- Grant the selected weapon
        LoadoutGrantModule.grant(player, { weaponName }, function(msg: string, ...: any)
            Logger.warn(TAG, msg, ...)
        end)
    end)
end

return RNGService
