--!strict
local Configs = script.Parent.Configs
local result: { [string]: any } = {}

local function absorb(t: { [string]: any })
	for k, v in t do
		result[k] = v
	end
end

absorb(require(Configs.ZombieConfig)  :: { [string]: any })
absorb(require(script.Parent.CombatConfig)  :: { [string]: any })
absorb(require(Configs.EconomyConfig) :: { [string]: any })
absorb(require(Configs.WaveConfig)    :: { [string]: any })
absorb(require(Configs.PlayerConfig)  :: { [string]: any })
absorb(require(Configs.DebugConfig)   :: { [string]: any })
absorb(require(Configs.GameConfig)   :: { [string]: any })

return result
