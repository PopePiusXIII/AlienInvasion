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

local replicated_storage = game:GetService("ReplicatedStorage")
local server_script_service = game:GetService("ServerScriptService")

local Framework     = require(replicated_storage.shared.framework)
local Logger        = require(replicated_storage.shared.logger)
local Config        = require(replicated_storage.shared.Config)
local RemoteNames   = require(replicated_storage.shared.RemoteNames)
local ZombieService = require(server_script_service.Match.services.ZombieService)
local EconomyService = require(script.Parent.EconomyService)
local GunModule     = require(replicated_storage.shared.gun_core)
local ProfileService = require(server_script_service.ProfileService)

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
		if not zombieModel:IsA("Model") then return end
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
			local waveNumber = tonumber(player:GetAttribute("CurrentWave")) or Config.STARTING_WAVE
			EconomyService.grantKillRewards(player, zombieType, waveNumber, deathPosition)
		end
	end)

	Logger.info(TAG, "ShootGun handler registered.")
end

return CombatService
