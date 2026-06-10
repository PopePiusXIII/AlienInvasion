--!strict
--------------------------------------------------------------------------------
-- Logger.luau  (packages/shared → ReplicatedStorage.Shared.Logger)
-- Centralized structured logging with a network middleware pipeline.
--
-- NETWORK MIDDLEWARE — the key observability tool:
--   wrapServerEvent(remote, tag, handler)
--     Connects OnServerEvent. Every call is:
--       1. Logged when Config.DEBUG_NETWORKING is true (direction, remote name, args)
--       2. Wrapped in pcall so a crashing handler never freezes the server thread.
--
--   wrapClientEvent(remote, tag, handler)
--     Same as above for client-side OnClientEvent.
--
--   fireClient / fireAllClients / fireServer
--     Drop-in replacements for :FireClient / :FireAllClients / :FireServer.
--     Each logs the direction + args when DEBUG_NETWORKING is true.
--
-- HOT-TOGGLE in Studio console:
--   require(game.ReplicatedStorage.Shared.Logger).DEBUG_NETWORKING = true
--------------------------------------------------------------------------------

local Config = require(script.Parent.Config)

local Logger = {}

-- Master network trace toggle. Flip to true in Config or at runtime to see
-- every single RemoteEvent payload passing through the middleware.
Logger.DEBUG_NETWORKING = Config.DEBUG_NETWORKING
-- High-frequency verbose toggle (e.g. per-frame AI logs).
Logger.DEBUG_VERBOSE = Config.DEBUG_VERBOSE

-- ── Internal ─────────────────────────────────────────────────────────────────

local function ts(): string
	return string.format("%.3f", os.clock())
end

local function format(msg: string, ...: any): string
	if select("#", ...) > 0 then
		return string.format(msg, ...)
	end
	return msg
end

local function serializeArgs(...: any): string
	local parts: { string } = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	return table.concat(parts, " | ")
end

local function netTrace(direction: string, remoteName: string, ...: any)
	if not Logger.DEBUG_NETWORKING then return end
	print(string.format("[NET][%s] %-20s  %-6s  { %s }",
		ts(), remoteName, direction, serializeArgs(...)))
end

-- ── Public log functions ──────────────────────────────────────────────────────

function Logger.info(tag: string, msg: string, ...: any)
	print(string.format("[%s][%s] %s", ts(), tag, format(msg, ...)))
end

function Logger.warn(tag: string, msg: string, ...: any)
	warn(string.format("[%s][%s] %s", ts(), tag, format(msg, ...)))
end

--- High-frequency log; only prints when Logger.DEBUG_VERBOSE is true.
function Logger.verbose(tag: string, msg: string, ...: any)
	if not Logger.DEBUG_VERBOSE then return end
	print(string.format("[VERBOSE][%s][%s] %s", ts(), tag, format(msg, ...)))
end

-- ── Network middleware ────────────────────────────────────────────────────────

--- SERVER — Connect a RemoteEvent.OnServerEvent with:
---   • pcall isolation: a crashing handler will warn but never freeze the thread.
---   • net trace: logged when Logger.DEBUG_NETWORKING == true.
---
--- Use this everywhere instead of remote.OnServerEvent:Connect(handler).
function Logger.wrapServerEvent(
	remote:  RemoteEvent,
	tag:     string,
	handler: (player: Player, ...any) -> ()
)
	remote.OnServerEvent:Connect(function(player: Player, ...)
		netTrace("C→S", remote.Name, player.Name, ...)
		local ok, err = pcall(handler, player, ...)
		if not ok then
			Logger.warn(tag, "OnServerEvent CRASHED [%s]: %s", remote.Name, tostring(err))
		end
	end)
end

--- CLIENT — Connect a RemoteEvent.OnClientEvent with pcall isolation + net trace.
---
--- Use this everywhere instead of remote.OnClientEvent:Connect(handler).
function Logger.wrapClientEvent(
	remote:  RemoteEvent,
	tag:     string,
	handler: (...any) -> ()
)
	remote.OnClientEvent:Connect(function(...)
		netTrace("S→C", remote.Name, ...)
		local ok, err = pcall(handler, ...)
		if not ok then
			Logger.warn(tag, "OnClientEvent CRASHED [%s]: %s", remote.Name, tostring(err))
		end
	end)
end

--- SERVER — Fire a RemoteEvent to a single client, with net trace.
function Logger.fireClient(remote: RemoteEvent, player: Player, ...: any)
	netTrace("S→"..player.Name, remote.Name, ...)
	remote:FireClient(player, ...)
end

--- SERVER — Fire a RemoteEvent to all clients, with net trace.
function Logger.fireAllClients(remote: RemoteEvent, ...: any)
	netTrace("S→ALL", remote.Name, ...)
	remote:FireAllClients(...)
end

--- CLIENT — Fire a RemoteEvent to the server, with net trace.
function Logger.fireServer(remote: RemoteEvent, ...: any)
	netTrace("C→S", remote.Name, ...)
	remote:FireServer(...)
end

return Logger
