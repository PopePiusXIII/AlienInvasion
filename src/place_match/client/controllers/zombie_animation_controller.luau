--!strict
--------------------------------------------------------------------------------
-- ZombieAnimationController
-- Thin controller that starts the client-side ZombieAnimationManager.
--------------------------------------------------------------------------------

local replicated_storage = game:GetService("ReplicatedStorage")

local Framework = require(replicated_storage.common.shared.framework)
local Logger = require(replicated_storage.common.shared.logger)

local TAG = "ZombieAnimationController"
local ZombieAnimationController = Framework.CreateController({ Name = TAG })

local ZombieAnimationManager = require(replicated_storage.match.client.controllers.modules.zombie.zombie_animation_manager)

function ZombieAnimationController:Init()
    -- no-op
end

function ZombieAnimationController:Start()
    -- Start the manager which will silently no-op for zombies without animations
    ZombieAnimationManager.Start()
    Logger.info(TAG, "Started ZombieAnimationManager")
end

return ZombieAnimationController
