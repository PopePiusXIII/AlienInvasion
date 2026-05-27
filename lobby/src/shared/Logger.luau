--!strict
--------------------------------------------------------------------------------
-- Logger.luau  (lobby/src/shared — ReplicatedStorage.Shared.Logger)
-- Identical to the Match Place Logger. Duplicated per-place (see Framework note).
-- Toggle DEBUG_NETWORKING in lobby/src/shared/Config.luau or at runtime.
--------------------------------------------------------------------------------

local Config = require(script.Parent.Config)

local Logger = {}

Logger.DEBUG_NETWORKING: boolean = Config.DEBUG_NETWORKING or false
Logger.DEBUG_VERBOSE:    boolean = Config.DEBUG_VERBOSE    or false

local function ts(): string
	return string.format("%.3f", os.clock())
end

local function format(msg: string, ...: any): string
	if select("#", ...) > 0 then return string.format(msg, ...) end
	return msg
end

local function serializeArgs(...: any): string
	local parts: { string } = {}
	for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
	return table.concat(parts, " | ")
end

local function netTrace(direction: string, remoteName: string, ...: any)
	if not Logger.DEBUG_NETWORKING then return end
	print(string.format("[NET][%s] %-20s  %-6s  { %s }",
		ts(), remoteName, direction, serializeArgs(...)))
end

function Logger.info(tag: string, msg: string, ...: any)
	print(string.format("[%s][%s] %s", ts(), tag, format(msg, ...)))
end

function Logger.warn(tag: string, msg: string, ...: any)
	warn(string.format("[%s][%s] %s", ts(), tag, format(msg, ...)))
end

function Logger.verbose(tag: string, msg: string, ...: any)
	if not Logger.DEBUG_VERBOSE then return end
	print(string.format("[VERBOSE][%s][%s] %s", ts(), tag, format(msg, ...)))
end

function Logger.wrapServerEvent(remote: RemoteEvent, tag: string, handler: (player: Player, ...any) -> ())
	remote.OnServerEvent:Connect(function(player: Player, ...)
		netTrace("C→S", remote.Name, player.Name, ...)
		local ok, err = pcall(handler, player, ...)
		if not ok then
			Logger.warn(tag, "OnServerEvent CRASHED [%s]: %s", remote.Name, tostring(err))
		end
	end)
end

function Logger.wrapClientEvent(remote: RemoteEvent, tag: string, handler: (...any) -> ())
	remote.OnClientEvent:Connect(function(...)
		netTrace("S→C", remote.Name, ...)
		local ok, err = pcall(handler, ...)
		if not ok then
			Logger.warn(tag, "OnClientEvent CRASHED [%s]: %s", remote.Name, tostring(err))
		end
	end)
end

function Logger.fireClient(remote: RemoteEvent, player: Player, ...: any)
	netTrace("S→"..player.Name, remote.Name, ...)
	remote:FireClient(player, ...)
end

function Logger.fireAllClients(remote: RemoteEvent, ...: any)
	netTrace("S→ALL", remote.Name, ...)
	remote:FireAllClients(...)
end

function Logger.fireServer(remote: RemoteEvent, ...: any)
	netTrace("C→S", remote.Name, ...)
	remote:FireServer(...)
end

return Logger
