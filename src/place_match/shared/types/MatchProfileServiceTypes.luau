-- !strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchProfile = require(ReplicatedStorage.Shared.MatchProfile)
local Framework = require(ReplicatedStorage.Shared.Framework)

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
