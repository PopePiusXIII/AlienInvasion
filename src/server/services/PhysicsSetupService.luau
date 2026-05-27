--!strict
--------------------------------------------------------------------------------
-- PhysicsSetupService.luau  (src/server/services)
-- Registers Roblox collision groups once at server startup.
-- Single Responsibility: world physics configuration — nothing else.
--------------------------------------------------------------------------------

local PhysicsService    = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)

local TAG = "PhysicsSetupService"

local PhysicsSetupService = Framework.CreateService({ Name = TAG })

function PhysicsSetupService:Init()
	-- pcall because registering an already-existing group throws in Studio.
	pcall(function() PhysicsService:RegisterCollisionGroup("Zombies") end)
	pcall(function() PhysicsService:RegisterCollisionGroup("ZombiePassthrough") end)
	PhysicsService:CollisionGroupSetCollidable("Zombies", "ZombiePassthrough", false)
	Logger.info(TAG, "Collision groups configured.")
end

return PhysicsSetupService
