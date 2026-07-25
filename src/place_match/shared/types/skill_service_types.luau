-- !strict
local replicated_storage = game:GetService("ReplicatedStorage")
local MatchProfile = require(replicated_storage.match.shared.types.match_profile)
local Framework = require(replicated_storage.common.shared.framework)

-- export type MatchProfileServiceT = Framework.Module & MatchProfileServiceTypes.API
export type API = {
	getGunModifiers: (player: Player) -> MatchProfile.GunModifer,
	getPlayerModifiers: (player: Player) -> MatchProfile.PlayerModifier,
	getModifierTypes: (player: Player) -> MatchProfile.FlatModifiers,
	apply: (player: Player, key: string) -> (),
}

 
return {}
