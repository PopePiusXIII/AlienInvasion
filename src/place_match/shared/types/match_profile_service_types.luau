-- !strict
local replicated_storage = game:GetService("ReplicatedStorage")
local MatchProfile = require(replicated_storage.shared.MatchProfile)
local Framework = require(replicated_storage.shared.framework)

-- export type MatchProfileServiceT = Framework.Module & MatchProfileServiceTypes.API
export type API = {
	getGunModifiers: (player: Player) -> MatchProfile.GunModifer,
	getPlayerModifiers: (player: Player) -> MatchProfile.PlayerModifier,
	getModifierTypes: (player: Player) -> MatchProfile.FlatModifiers,
	apply: (player: Player, key: string) -> (),
	Init: ((self: Framework.Module) -> ())?,
	Start: ((self: Framework.Module) -> ())?,
}

 
return {}
