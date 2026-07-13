--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local Logger    = require(ReplicatedStorage.Shared.Logger)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local TAG = "RngService"
local RngService = Framework.CreateService({ Name = TAG })

function RngService:Init()
	Logger.info(TAG, "Initialized.")
end

function RngService:Start()
	Logger.info(TAG, "Started.")
end

return RngService