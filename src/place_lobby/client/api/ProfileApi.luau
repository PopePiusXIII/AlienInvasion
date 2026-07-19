--!strict
--------------------------------------------------------------------------------
-- ProfileApi.luau
-- Client-facing facade for the server-owned ProfileService.
--
-- The ProfileStore and ProfileService stay on the server. This module exposes
-- the small client API needed by lobby UI and translates calls to remotes.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local ProfileApiType = require(ReplicatedStorage.Shared.ProfileApiType)

type ProfileSnapshot = ProfileApiType.ProfileSnapshot
type ProfileChangedCallback = ProfileApiType.ProfileChangedCallback
type OwnedItem = ProfileApiType.OwnedItem

local ProfileApi = {} :: ProfileApiType.API

local _syncProfileRemote: RemoteEvent?
local _purchaseWeaponRemote: RemoteEvent?
local _started = false
local _profile: ProfileSnapshot = {
	gold = 0,
	silver = 0,
	unlockedWeapons = {},
	inventory = {},
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
			warn("[ProfileApi] Profile listener failed")
		end
	end
end

--- Connects the client API to the server remotes.
--- Call once from a client controller's Start method.
function ProfileApi.start()
	if _started then
		return
	end

	_started = true
	local syncProfileRemote = Framework.GetRemote(RemoteNames.SYNC_PROFILE)
	_syncProfileRemote = syncProfileRemote
	_purchaseWeaponRemote = Framework.GetRemote(RemoteNames.PURCHASE_WEAPON)

	syncProfileRemote.OnClientEvent:Connect(function(
		gold: number,
		silver: number,
		unlockedWeapons: { string }?,
		inventory: { OwnedItem }?
	)
		_profile.gold = math.max(0, math.floor(gold))
		_profile.silver = math.max(0, math.floor(silver))
		_profile.unlockedWeapons = unlockedWeapons or {}
		_profile.inventory = inventory or {}
		notifyProfileChanged()
	end)
end

--- Returns the latest profile values received from the server.
function ProfileApi.getProfile(): ProfileSnapshot
	return copyProfile(_profile)
end

--- Subscribes to server profile updates. Returns an unsubscribe function.
function ProfileApi.onChanged(callback: ProfileChangedCallback): () -> ()
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

--- Requests a weapon purchase. The server validates the weapon and balance.
--- The updated balance arrives through SYNC_PROFILE.
function ProfileApi.purchaseWeapon(weaponName: string)
	assert(_started, "ProfileApi.start() must be called before purchaseWeapon()")
	local purchaseWeaponRemote = _purchaseWeaponRemote
	assert(purchaseWeaponRemote, "PurchaseWeapon remote was not initialized")
	purchaseWeaponRemote:FireServer(weaponName)
end

return ProfileApi
