--!strict
--------------------------------------------------------------------------------
-- Framework.luau  (lobby/src/shared — ReplicatedStorage.Shared.Framework)
-- Identical to the Match Place Framework. Duplicated because each Roblox place
-- has its own ReplicatedStorage; cross-place module sharing is not possible.
-- Keep both files in sync when making framework changes.
--------------------------------------------------------------------------------

local RunService = game:GetService("RunService")
local IS_SERVER  = RunService:IsServer()

local Framework = {}

export type Module = {
	Name:  string,
	Init:  ((self: Module) -> ())?,
	Start: ((self: Module) -> ())?,
	[any]: any,
}

local _registry: { [string]: Module } = {}
local _remoteFolder: Folder? = nil

local function getRemoteFolder(): Folder
	if _remoteFolder then return _remoteFolder :: Folder end
	local RS = game:GetService("ReplicatedStorage")
	if IS_SERVER then
		local f = RS:FindFirstChild("Remotes") :: Folder?
		if not f then
			f        = Instance.new("Folder") :: Folder
			f.Name   = "Remotes"
			f.Parent = RS
		end
		_remoteFolder = f
	else
		_remoteFolder = RS:WaitForChild("Remotes", 10) :: Folder
	end
	return _remoteFolder :: Folder
end

function Framework.CreateRemote(name: string): RemoteEvent
	assert(IS_SERVER, "[Framework] CreateRemote must be called on the server")
	local folder   = getRemoteFolder()
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then return existing :: RemoteEvent end
	local event  = Instance.new("RemoteEvent")
	event.Name   = name
	event.Parent = folder
	return event
end

function Framework.GetRemote(name: string): RemoteEvent
	assert(not IS_SERVER, "[Framework] GetRemote must be called on the client")
	return getRemoteFolder():WaitForChild(name) :: RemoteEvent
end

function Framework.CreateService(def: Module): Module
	assert(IS_SERVER, "[Framework] CreateService must be called on the server")
	assert(def.Name and def.Name ~= "", "[Framework] Service must have a non-empty Name")
	assert(not _registry[def.Name], "[Framework] Duplicate service: " .. def.Name)
	_registry[def.Name] = def
	return def
end

function Framework.CreateController(def: Module): Module
	assert(not IS_SERVER, "[Framework] CreateController must be called on the client")
	assert(def.Name and def.Name ~= "", "[Framework] Controller must have a non-empty Name")
	assert(not _registry[def.Name], "[Framework] Duplicate controller: " .. def.Name)
	_registry[def.Name] = def
	return def
end

function Framework.GetService(name: string): Module
	local m = _registry[name]
	assert(m, "[Framework] Module not found: " .. name)
	return m
end

Framework.GetController = Framework.GetService

function Framework.Start()
	for name, mod in pairs(_registry) do
		if mod.Init then
			local ok, err = pcall(mod.Init, mod)
			if not ok then
				warn(string.format("[Framework] Init FAILED (%s): %s", name, tostring(err)))
			end
		end
	end
	for name, mod in pairs(_registry) do
		if mod.Start then
			task.spawn(function()
				local ok, err = pcall(mod.Start, mod)
				if not ok then
					warn(string.format("[Framework] Start CRASHED (%s): %s", name, tostring(err)))
				end
			end)
		end
	end
end

return Framework
