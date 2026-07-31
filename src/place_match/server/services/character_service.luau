--!strict

local Players = game:GetService("Players")

local Framework = require(game:GetService("ReplicatedStorage").common.shared.framework)

local TAG = "CharacterService"

export type CharacterContext = {
	character: Model,
	humanoid: Humanoid,
}

local CharacterService = {}
CharacterService.Name = TAG

local _contexts: { [Player]: CharacterContext } = {}
local _characterConnections: { [Player]: { RBXScriptConnection } } = {}
local _characterReady = Instance.new("BindableEvent")
local _characterRemoved = Instance.new("BindableEvent")

local function disconnectPlayer(player: Player)
	local connections = _characterConnections[player]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		_characterConnections[player] = nil
	end

	local context = _contexts[player]
	if context then
		_contexts[player] = nil
		_characterRemoved:Fire(player, context)
	end
end

local function bindCharacter(player: Player, character: Model)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		if player.Character ~= character then return end

		local context = { character = character, humanoid = humanoid }
		_contexts[player] = context
		_characterReady:Fire(player, context)
	end)
end

local function watchPlayer(player: Player)
	_characterConnections[player] = {
		player.CharacterAdded:Connect(function(character: Model)
			bindCharacter(player, character)
		end),
		player.CharacterRemoving:Connect(function()
			local context = _contexts[player]
			if context then
				_contexts[player] = nil
				_characterRemoved:Fire(player, context)
			end
		end),
	}

	if player.Character then
		bindCharacter(player, player.Character)
	end
end

function CharacterService.get(player: Player): CharacterContext?
	return _contexts[player]
end

function CharacterService.getPlayer(character: Model): Player?
	for player, context in pairs(_contexts) do
		if context.character == character then
			return player
		end
	end
	return nil
end

function CharacterService.waitFor(player: Player): CharacterContext
	local context = _contexts[player]
	while not context do
		local readyPlayer = _characterReady.Event:Wait() :: Player
		if readyPlayer == player then
			context = _contexts[player]
		end
	end
	return context
end

function CharacterService.onCharacterReady(
	callback: (Player, CharacterContext) -> ()
): RBXScriptConnection
	local connection = _characterReady.Event:Connect(callback)
	for player, context in pairs(_contexts) do
		callback(player, context)
	end
	return connection
end

function CharacterService.onCharacterRemoved(
	callback: (Player, CharacterContext) -> ()
): RBXScriptConnection
	return _characterRemoved.Event:Connect(callback)
end

function CharacterService:Init() end

function CharacterService:Start()
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
end

Framework.CreateService(CharacterService)

return CharacterService
