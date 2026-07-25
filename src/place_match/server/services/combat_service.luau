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
local ServerScriptService = game:GetService("ServerScriptService")

local Framework     = require(ReplicatedStorage.Common.Shared.Framework)
local Logger        = require(ReplicatedStorage.Common.Shared.Logger)
local RemoteNames   = require(ReplicatedStorage.Match.Shared.RemoteNames)
local ZombieService = require(ServerScriptService.ServerModules.Match.Services.ZombieService)
local EconomyService = require(ServerScriptService.ServerModules.Match.Services.EconomyService)
local InventoryService = require(ServerScriptService.ServerModules.Match.Services.InventoryService)
local GunCore     = require(ReplicatedStorage.Common.Shared.GunCore)
local SkillService = require(ServerScriptService.ServerModules.Match.Services.SkillService)
local WaveConfig = require(ReplicatedStorage.Match.Shared.Configs.WaveConfig)

local CombatService = {}
local TAG = "CombatService"
CombatService.Name = TAG

function CombatService:Init()
	local shootRemote = Framework.CreateRemote(RemoteNames.SHOOT_GUN)
	local hitSoundRemote = Framework.CreateRemote(RemoteNames.ZOMBIE_HIT_SOUND)

	Logger.wrapServerEvent(shootRemote, TAG, function(player: Player, zombieModel: Instance, isHeadshot: boolean, hitPosition: Vector3)
		if not zombieModel:IsA("Model") then return end
		local character = player.Character

		-- Resolve equipped gun via InventoryService + SkillService
		local equippedGunId = InventoryService.getEquippedGunId(player)
		if not equippedGunId then return end

		-- Get current in-memory level for stat resolution
		local level = InventoryService.getGunLevel(player, equippedGunId)

		-- Get resolved stats (base rarity stats + level multipliers)
		local gun = SkillService.getGunStats(player, equippedGunId, level) :: GunCore.Gun?
		if not gun then return end

		local shooterPos: Vector3?
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				shooterPos = hrp.Position
			end
		end
		local killed, zombieType, deathPosition = ZombieService.damageZombie(
			zombieModel,
			gun,
			isHeadshot,
			shooterPos
		)

		Logger.fireClient(hitSoundRemote, player, hitPosition, isHeadshot)

		if killed then
			local waveNumber = tonumber(player:GetAttribute("CurrentWave")) or WaveConfig.STARTING_WAVE
			EconomyService.grantKillRewards(player, zombieType, waveNumber, deathPosition)
		end
	end)

	Logger.info(TAG, "ShootGun handler registered.")
end

function CombatService:Start()
	-- Any startup logic for the CombatService can go here
end

CombatService = Framework.CreateService(CombatService)

return CombatService
