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

local TAG = "CombatService"

local CombatService = Framework.CreateService({ Name = TAG })

function CombatService:Init()
	local shootRemote = Framework.CreateRemote(RemoteNames.SHOOT_GUN)
	local hitSoundRemote = Framework.CreateRemote(RemoteNames.ZOMBIE_HIT_SOUND)

	Logger.wrapServerEvent(shootRemote, TAG, function(player: Player, zombieModel: Instance, isHeadshot: boolean, hitPosition: Vector3)
		if not zombieModel then return end
		local character = player.Character

		-- Server-authoritative gun resolution: read from the equipped Tool, not from client input.
		local equippedTool = character and character:FindFirstChildWhichIsA("Tool") :: Tool?
		local serverGunName: string? = if equippedTool then equippedTool.Name else nil

		local shooterPos: Vector3?
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			shooterPos = hrp and hrp.Position or nil
		end
		local killed, zombieType, deathPosition = ZombieService.damageZombie(
			zombieModel :: Model?,
			serverGunName,
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
