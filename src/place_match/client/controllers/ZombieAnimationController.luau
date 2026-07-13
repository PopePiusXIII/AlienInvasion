--!strict
--------------------------------------------------------------------------------
-- ZombieAnimationController
-- Thin controller that starts the client-side ZombieAnimationManager.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger = require(ReplicatedStorage.Shared.Logger)

local TAG = "ZombieAnimationController"
local ZombieAnimationController = Framework.CreateController({ Name = TAG })

local ZombieAnimationManager = require(script.Parent.modules.zombie.ZombieAnimationManager)

function ZombieAnimationController:Init()
    -- no-op
end

function ZombieAnimationController:Start()
    -- Start the manager which will silently no-op for zombies without animations
    ZombieAnimationManager.Start()
    Logger.info(TAG, "Started ZombieAnimationManager")
end

return ZombieAnimationController
