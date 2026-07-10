--!strict
--------------------------------------------------------------------------------
-- CombatService.luau  (src/server/services)
-- Owns the ShootGun RemoteEvent.
-- Receives hit reports from the client and applies server-authoritative damage.
-- Single Responsibility: server-side hit validation and damage routing.
--
-- Security notes:
--   • The client sends the Instance it thinks it hit. Server re-validates:
--     name == "Zombie", parent == workspace, has a live Humanoid.
--   • Gun name is resolved server-side from the player's equipped Tool — client input is ignored.
--   • ZombieService.damageZombie() is the authoritative damage gate.
--   • Logger.wrapServerEvent() pcall-isolates this handler from the server thread.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework     = require(ReplicatedStorage.Shared.Framework)
local Logger        = require(ReplicatedStorage.Shared.Logger)
local Config        = require(ReplicatedStorage.Shared.Config)
local RemoteNames   = require(ReplicatedStorage.Shared.RemoteNames)
local ZombieService = require(script.Parent.ZombieService)
local EconomyService = require(script.Parent.EconomyService)
local GunModule     = require(ReplicatedStorage.Shared.GunCore)
local ProfileService = require(ReplicatedStorage.Shared.ProfileService)

local TAG = "CombatService"

local CombatService = Framework.CreateService({ Name = TAG })

--- Lazy-loaded to avoid circular dependency.
local InventoryService = nil

local function ensureInventoryService()
	if not InventoryService then
		InventoryService = Framework.GetService("InventoryService")
	end
end

function CombatService:Init()
	local shootRemote = Framework.CreateRemote(RemoteNames.SHOOT_GUN)
	local hitSoundRemote = Framework.CreateRemote(RemoteNames.ZOMBIE_HIT_SOUND)

	Logger.wrapServerEvent(shootRemote, TAG, function(player: Player, zombieModel: Instance, isHeadshot: boolean, hitPosition: Vector3)
		if not zombieModel then return end
		local character = player.Character

		-- Resolve equipped gun via InventoryService + ProfileService
		ensureInventoryService()
		local equippedGunId = InventoryService.getEquippedGunId(player)
		if not equippedGunId then return end

		-- Get current in-memory level for stat resolution
		local level = InventoryService.getGunLevel(player, equippedGunId)

		-- Get resolved stats (base rarity stats + level multipliers)
		local gun = ProfileService.getGunStats(player, equippedGunId, level) :: GunModule.Gun?
		if not gun then return end

		local shooterPos: Vector3?
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			shooterPos = hrp and hrp.Position or nil
		end
		local killed, zombieType, deathPosition = ZombieService.damageZombie(
			zombieModel :: Model?,
			gun,
			isHeadshot,
			shooterPos
		)

		Logger.fireClient(hitSoundRemote, player, hitPosition, isHeadshot)

		if killed then
			local waveNumber = tonumber(player:GetAttribute("CurrentWave")) or Config.STARTING_WAVE
			EconomyService.grantKillRewards(player, zombieType, waveNumber, deathPosition)
		end
	end)

	Logger.info(TAG, "ShootGun handler registered.")
end

return CombatService
