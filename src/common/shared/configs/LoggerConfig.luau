--!strict
local Configs = script.Parent.Configs
local result: { [string]: any } = {}

local function absorb(t: { [string]: any })
	for k, v in t do
		result[k] = v
	end
end

absorb(require(Configs.CombatConfig)  :: { [string]: any })


return result
