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

local framework      = require(replicated_storage.common.shared.framework)
local logger         = require(replicated_storage.common.shared.logger)
local remote_names   = require(replicated_storage.match.shared.remote_names)
local zombie_service = require(server_script_service.match.services.zombie_service)
local economy_service = require(server_script_service.match.services.economy_service)
local inventory_service = require(server_script_service.match.services.inventory_service)
local gun_core       = require(replicated_storage.common.shared.gun_core)
local profile_service = require(server_script_service.common.services.profile_db)
local wave_config    = require(replicated_storage.match.shared.configs.wave_config)

local combat_service = {}
local TAG = "CombatService"
combat_service.Name = TAG

function combat_service:Init()
	local shoot_remote = framework.CreateRemote(remote_names.SHOOT_GUN)
	local hit_sound_remote = framework.CreateRemote(remote_names.ZOMBIE_HIT_SOUND)
	local damage_dealt_remote = framework.CreateRemote(remote_names.ZOMBIE_DAMAGE_DEALT)

	logger.onServerEvent(shoot_remote, TAG, function(player: Player, zombie_model: Instance, is_headshot: boolean, hit_position: Vector3)
		if not zombie_model or not zombie_model:IsA("Model") then return end
		local character = player.Character

		-- Resolve equipped gun via inventory_service + profile_service
		local equipped_gun_id = inventory_service.getEquippedGunId(player)
		if not equipped_gun_id then return end

		-- Get current in-memory level for stat resolution
		local level = inventory_service.getGunLevel(player, equipped_gun_id)

		-- Get resolved stats (base rarity stats + level multipliers)
		local gun = profile_service.getGunStats(player, equipped_gun_id, level) :: gun_core.Gun?
		if not gun then return end

		local shooter_pos: Vector3?
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				shooter_pos = hrp.Position
			end
		end
		local killed, zombie_type, death_position, damage_amount = zombie_service.damageZombie(
			zombie_model,
			gun,
			is_headshot,
			shooter_pos
		)

		logger.fireClient(hit_sound_remote, player, hit_position, is_headshot)
		if damage_amount then
			logger.fireClient(damage_dealt_remote, player, zombie_model, damage_amount, is_headshot)
		end

		if killed then
			local wave_number = tonumber(player:GetAttribute("CurrentWave")) or wave_config.STARTING_WAVE
			economy_service.grantKillRewards(player, zombie_type, wave_number, death_position)
		end
	end)

	logger.info(TAG, "ShootGun handler registered.")
end

function combat_service:Start()
	-- Any startup logic for the combat_service can go here
end

combat_service = framework.CreateService(combat_service)

return combat_service
