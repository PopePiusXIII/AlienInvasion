--!strict
--------------------------------------------------------------------------------
-- Framework.luau  (src/shared → ReplicatedStorage.Shared.Framework)
-- Lightweight Service/Controller bootstrapper for AlienInvasion.
--
-- SERVER usage:
--   local MyService = Framework.CreateService({ Name = "MyService" })
--   function MyService:Init()  ...  end   -- sync, no yields
--   function MyService:Start() ...  end   -- async, yielding OK
--   return MyService
--   -- Then in ServerRuntime: require all services, Framework.Start()
--
-- CLIENT usage: identical, but use CreateController instead.
--
-- Lifecycle contract:
--   Init()  — All services/controllers are registered. NO yields. Safe to store
--             peer references via Framework.GetService(). Do NOT call peer methods.
--   Start() — All Init()s have completed. Each Start() runs in its own thread.
--             Yielding and cross-service method calls are both safe here.
--
-- Remote pipeline:
--   Server: Framework.CreateRemote(name)  → creates RemoteEvent under RS.Remotes
--   Client: Framework.GetRemote(name)     → WaitForChild on RS.Remotes
--   All remote interaction should be logged through Logger.wrapServerEvent /
--   Logger.wrapClientEvent for crash isolation and payload tracing.
--------------------------------------------------------------------------------

local RunService = game:GetService("RunService")
local IS_SERVER  = RunService:IsServer()

local Framework = {}

-- ── Type ─────────────────────────────────────────────────────────────────────

export type Module = {
	Name:  string,
	Init:  ((self: Module) -> ())?,
	Start: ((self: Module) -> ())?,
	[any]: any,
}

-- ── Internal registry ─────────────────────────────────────────────────────────

local _registry: { [string]: Module } = {}

-- ── Remote folder ─────────────────────────────────────────────────────────────
-- Server creates it; client waits up to 10 s (well within server boot time).

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

-- ── Remote factory ────────────────────────────────────────────────────────────

--- SERVER ONLY. Creates (or returns existing) a RemoteEvent under RS.Remotes.
--- Call during Init() so remotes exist before any client connects.
function Framework.CreateRemote(name: string): RemoteEvent
	assert(IS_SERVER, "[Framework] CreateRemote must be called on the server")
	local folder   = getRemoteFolder()
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing :: RemoteEvent
	end

	local event  = Instance.new("RemoteEvent")
	event.Name   = name
	event.Parent = folder

	if not _remoteFolder then
		error("[Framework] Failed to get Remote folder under ReplicatedStorage")
	else
		warn("[Framework] Created RemoteEvent '" .. name .. "' under ReplicatedStorage.Remotes")
	end

	return event
end

--- CLIENT ONLY. Waits for and returns a RemoteEvent from RS.Remotes.
--- Call during Start() after all server Inits have run.
function Framework.GetRemote(name: string): RemoteEvent
	assert(not IS_SERVER, "[Framework] GetRemote must be called on the client")
	warn("[Framework] GetRemote called for '" .. name .. "'; waiting for RemoteEvent under ReplicatedStorage.Remotes")
	return getRemoteFolder():WaitForChild(name) :: RemoteEvent
end

--- SERVER ONLY. Creates (or returns existing) a RemoteFunction under RS.Remotes.
function Framework.CreateRemoteFunction(name: string): RemoteFunction
	assert(IS_SERVER, "[Framework] CreateRemoteFunction must be called on the server")
	local folder   = getRemoteFolder()
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing :: RemoteFunction
	end
	local fn   = Instance.new("RemoteFunction")
	fn.Name    = name
	fn.Parent  = folder
	return fn
end

--- CLIENT ONLY. Waits for and returns a RemoteFunction from RS.Remotes.
function Framework.GetRemoteFunction(name: string): RemoteFunction
	assert(not IS_SERVER, "[Framework] GetRemoteFunction must be called on the client")
	return getRemoteFolder():WaitForChild(name) :: RemoteFunction
end

-- ── Registration ──────────────────────────────────────────────────────────────

--- Register a server Service. Call at module level (not inside a function).
function Framework.CreateService(def: Module): Module
	assert(IS_SERVER, "[Framework] CreateService must be called on the server")
	assert(def.Name and def.Name ~= "", "[Framework] Service must have a non-empty Name")
	assert(not _registry[def.Name], "[Framework] Duplicate service: " .. def.Name)
	_registry[def.Name] = def
	return def
end

--- Register a client Controller. Call at module level (not inside a function).
function Framework.CreateController(def: Module): Module
	assert(not IS_SERVER, "[Framework] CreateController must be called on the client")
	assert(def.Name and def.Name ~= "", "[Framework] Controller must have a non-empty Name")
	assert(not _registry[def.Name], "[Framework] Duplicate controller: " .. def.Name)
	_registry[def.Name] = def
	return def
end

--- Retrieve a registered Service/Controller by name.
--- Safe to call during Init() to store references; do NOT call methods until Start().
function Framework.GetService(name: string): Module
	local m = _registry[name]
	assert(m, "[Framework] Module not found: " .. name)
	return m
end

-- Alias for clarity on the client side.
Framework.GetController = Framework.GetService

-- ── Bootstrapper ──────────────────────────────────────────────────────────────

--- Call ONCE in the runtime entry point after all modules are required.
---
--- Phase 1 — Init: synchronous, iterates all registered modules.
---            A crashed Init does NOT halt others (pcall-isolated).
--- Phase 2 — Start: each module runs in its own task.spawn.
---            A crashed Start does NOT cascade to other modules (crash-isolated).
function Framework.Start()
	-- Phase 1: synchronous Init — no yielding.
	for name, mod in pairs(_registry) do
		warn(string.format("[Framework] Init %s", name))
		if mod.Init then
			local ok, err = pcall(mod.Init, mod)
			if not ok then
				warn(string.format("[Framework] Init FAILED (%s): %s", name, tostring(err)))
			end
		end
	end

	-- Phase 2: concurrent Start — each thread is fully isolated.
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
