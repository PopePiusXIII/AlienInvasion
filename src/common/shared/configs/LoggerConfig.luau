--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Configs = ReplicatedStorage.Shared.Configs
local result: { [string]: any } = {}

local function absorb(t: { [string]: any })
	for k, v in t do
		result[k] = v
	end
end

absorb(require(Configs.Common.CombatConfig)  :: { [string]: any })


return result
