--!strict

-- A logger is created from a config ModuleScript with LoggerModule.newLogger(configModule).
-- The module also returns a default logger so existing callers that do
-- `require(...logger).info(...)` continue to work.

export type LoggerConfig = {
	DEBUG_NETWORKING: boolean,
	DEBUG_VERBOSE: boolean,
}

export type Logger = {
	DEBUG_NETWORKING: boolean,
	DEBUG_VERBOSE: boolean,

	info: (tag: string, msg: string, ...any) -> (),
	warn: (tag: string, msg: string, ...any) -> (),
	verbose: (tag: string, msg: string, ...any) -> (),
	wrapServerEvent: (remote: RemoteEvent, tag: string, handler: (player: Player, ...any) -> ()) -> RBXScriptConnection,
	wrapClientEvent: (remote: RemoteEvent, tag: string, handler: (...any) -> ()) -> RBXScriptConnection,
	fireClient: (remote: RemoteEvent, player: Player, ...any) -> (),
	fireAllClients: (remote: RemoteEvent, ...any) -> (),
	fireServer: (remote: RemoteEvent, ...any) -> (),
}

export type LoggerModule = Logger & {
	new: (configModule: ModuleScript) -> Logger,
}

local function timestamp(): string
	return string.format("%.3f", os.clock())
end

local function formatMessage(msg: string, ...: any): string
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

local function makeLogger(config: LoggerConfig): Logger
	local logger: Logger

	local function netTrace(direction: string, remoteName: string, ...: any)
		if not logger.DEBUG_NETWORKING then
			return
		end

		print(string.format("[NET][%s] %-20s  %-6s  { %s }",
			timestamp(), remoteName, direction, serializeArgs(...)))
	end

	logger = {
		DEBUG_NETWORKING = config.DEBUG_NETWORKING,
		DEBUG_VERBOSE = config.DEBUG_VERBOSE,

		info = function(tag: string, msg: string, ...: any)
			print(string.format("[%s][%s] %s", timestamp(), tag, formatMessage(msg, ...)))
		end,

		warn = function(tag: string, msg: string, ...: any)
			warn(string.format("[%s][%s] %s", timestamp(), tag, formatMessage(msg, ...)))
		end,

		verbose = function(tag: string, msg: string, ...: any)
			if not logger.DEBUG_VERBOSE then
				return
			end
			print(string.format("[VERBOSE][%s][%s] %s", timestamp(), tag, formatMessage(msg, ...)))
		end,

		wrapServerEvent = function(
			remote: RemoteEvent,
			tag: string,
			handler: (player: Player, ...any) -> ()
		): RBXScriptConnection
			return remote.OnServerEvent:Connect(function(player: Player, ...)
				netTrace("C→S", remote.Name, player.Name, ...)
				local ok, err = pcall(handler :: (Player, ...any) -> any, player, ...)
				if not ok then
					logger.warn(tag, "OnServerEvent CRASHED [%s]: %s", remote.Name, tostring(err))
				end
			end)
		end,

		wrapClientEvent = function(
			remote: RemoteEvent,
			tag: string,
			handler: (...any) -> ()
		): RBXScriptConnection
			return remote.OnClientEvent:Connect(function(...)
				netTrace("S→C", remote.Name, ...)
				local ok, err = pcall(handler :: (...any) -> any, ...)
				if not ok then
					logger.warn(tag, "OnClientEvent CRASHED [%s]: %s", remote.Name, tostring(err))
				end
			end)
		end,

		fireClient = function(remote: RemoteEvent, player: Player, ...: any)
			netTrace("S→" .. player.Name, remote.Name, ...)
			remote:FireClient(player, ...)
		end,

		fireAllClients = function(remote: RemoteEvent, ...: any)
			netTrace("S→ALL", remote.Name, ...)
			remote:FireAllClients(...)
		end,

		fireServer = function(remote: RemoteEvent, ...: any)
			netTrace("C→S", remote.Name, ...)
			remote:FireServer(...)
		end,

	}

	return logger
end

local function newLogger(configModule: ModuleScript): Logger
	local config = require(configModule) :: LoggerConfig
	return makeLogger(config)
end

-- Safe defaults keep the logger usable in both the lobby and match places.
local defaultLogger = makeLogger({
	DEBUG_NETWORKING = false,
	DEBUG_VERBOSE = false,
}) :: LoggerModule
defaultLogger.new = newLogger

return defaultLogger
