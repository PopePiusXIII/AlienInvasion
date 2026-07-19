--!strict
--------------------------------------------------------------------------------
-- UiLabsApi.luau
-- Local ProfileApi implementation for UI Labs stories.
--
-- This intentionally has the same public API as ProfileApi, but never gets a
-- remote or server connection. Stories can use it to exercise UI reactions.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileApiType = require(ReplicatedStorage.Shared.ProfileApiType)

type ProfileSnapshot = ProfileApiType.ProfileSnapshot
type ProfileChangedCallback = ProfileApiType.ProfileChangedCallback

local UiLabsApi = {} :: ProfileApiType.API

local _started = false
local _profile: ProfileSnapshot = {
	gold = 80,
	silver = 1250,
	unlockedWeapons = { "1911", "HandCannon", "MP5", "SCAR" },
	inventory = {
		{ id = "UI-LABS-1911", name = "1911", rarity = "common" },
		{ id = "UI-LABS-MP5", name = "MP5", rarity = "rare" },
	},
}
local _listeners: { ProfileChangedCallback } = {}

local function copyProfile(profile: ProfileSnapshot): ProfileSnapshot
	return {
		gold = profile.gold,
		silver = profile.silver,
		unlockedWeapons = table.clone(profile.unlockedWeapons),
		inventory = table.clone(profile.inventory),
	}
end

local function notifyProfileChanged()
	local snapshot = copyProfile(_profile)
	for _, listener in _listeners do
		local ok = pcall(function()
			listener(snapshot)
		end)
		if not ok then
			warn("[UiLabsApi] Profile listener failed")
		end
	end
end

function UiLabsApi.start()
	if _started then
		return
	end

	_started = true
	notifyProfileChanged()
end

function UiLabsApi.getProfile(): ProfileSnapshot
	return copyProfile(_profile)
end

function UiLabsApi.onChanged(callback: ProfileChangedCallback): () -> ()
	table.insert(_listeners, callback)
	if _started then
		callback(copyProfile(_profile))
	end

	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false

		local index = table.find(_listeners, callback)
		if index then
			table.remove(_listeners, index)
		end
	end
end

function UiLabsApi.purchaseWeapon(weaponName: string)
	assert(_started, "UiLabsApi.start() must be called before purchaseWeapon()")
	warn("[UiLabsApi] Mock purchase request: " .. weaponName)
end

return UiLabsApi
