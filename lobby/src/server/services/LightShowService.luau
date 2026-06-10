--!strict
--------------------------------------------------------------------------------
-- LightShowService.luau  (lobby/src/server/services)
-- Manages stadium light shows synchronized with lobby music.
--
-- Logic:
-- 1. Scans Workspace for groups (e.g. "StadiumLighta")
-- 2. Within those, finds light parts (e.g. "StadiumLight 1")
-- 3. Toggles shared SpotLights under LightPart1/2 and UsePartColor on housing.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework         = require(ReplicatedStorage.Shared.Framework)
local Logger            = require(ReplicatedStorage.Shared.Logger)

local TAG = "LightShowService"

export type LightStep = {
	group:     string,
	index:     number | string,
	duration:  number,
	startTime: number,
}

local LightShowService = Framework.CreateService({ Name = TAG })

-- Registry: GroupID -> { [Index]: BasePart }
local _lightGroups: { [string]: { [number]: BasePart } } = {}
-- GroupID -> { [string]: Instance } (e.g. "a" -> { "LightPart1": Instance })
local _sharedParts: { [string]: { [string]: Instance } } = {}

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function LightShowService:Init()
	Logger.info(TAG, "Initializing Service...")
	
	-- Robust scan: Search throughout Workspace for any item named StadiumLight...
	local function scan(parent: Instance)
		for _, child in ipairs(parent:GetChildren()) do
			-- Check if this is a Light Group (e.g. StadiumLighta, StadiumLightb)
			local groupMatch = child.Name:match("^StadiumLight%s*(%a+)$")
			
			if groupMatch then
				local groupId = groupMatch:lower()
				_lightGroups[groupId] = {}
				_sharedParts[groupId] = {}
				Logger.info(TAG, "Found group: %s (ID: %s)", child:GetFullName(), groupId)

				-- Find SHARED light parts directly under the group
				for _, pName in { "LightPart1", "LightPart2" } do
					local found = child:FindFirstChild(pName)
					if found then
						_sharedParts[groupId][pName] = found
						Logger.info(TAG, "  Found shared container: %s", pName)
					end
				end

				for _, lightItem in ipairs(child:GetChildren()) do
					-- Look for light housing parts (e.g. StadiumLight1, StadiumLight 2)
					local indexMatch = lightItem.Name:match("StadiumLight%s*(%d+)")
					if indexMatch and lightItem:IsA("BasePart") then
						local index = tonumber(indexMatch)
						if index then
							_lightGroups[groupId][index] = lightItem
							Logger.info(TAG, "  Registered housing: %s (Index: %d)", lightItem.Name, index)
							self:_setLightState(groupId, index, false)
						end
					end
				end
				
				local count = 0
				for _ in pairs(_lightGroups[groupId]) do count += 1 end
				Logger.info(TAG, "Finalized group '%s' with %d housing parts", groupId, count)

			elseif not child.Name:match("StadiumLight") then
				-- Recursively scan if it's a folder/model but not related to stadium lights
				if child:IsA("Folder") or child:IsA("Model") then
					scan(child)
				end
			end
		end
	end

	scan(game.Workspace)

	if next(_lightGroups) == nil then
		Logger.warn(TAG, "No StadiumLight groups were found in Workspace!")
	end
end

function LightShowService:Start()
	Logger.info(TAG, "Service live.")
	
	-- Auto-start the Iron Cartilage show
	task.defer(function()
		local Config = require(ReplicatedStorage.Shared.LightShowConfig)
		local baseShow = Config.GetIronCartilageShow()
		local duration = Config.GetSequenceDuration(baseShow)
		local sequence = Config.GetLoopedSequence(baseShow, 20, duration)
		
		Logger.info(TAG, "Starting Iron Cartilage show sequence (Lobby)...")
		self:PlaySequence(sequence)
	end)
end

-- ── Public API ───────────────────────────────────────────────────────────────

--- Plays an array of timed light events.
function LightShowService:PlaySequence(sequence: { LightStep })
	Logger.info(TAG, "Playing sequence with %d steps", #sequence)
	
	for _, step in ipairs(sequence) do
		task.delay(step.startTime, function()
			self:Flash(step.group, step.index, step.duration)
		end)
	end
end

--- Flashes a single light or all lights in a group.
function LightShowService:Flash(group: string, index: number | string, duration: number)
	local groupId = group:lower()
	local lights = _lightGroups[groupId]
	if not lights then return end

	if index == "all" then
		for idx, _ in pairs(lights) do
			task.spawn(function()
				self:_setLightState(groupId, idx, true)
				task.wait(duration)
				self:_setLightState(groupId, idx, false)
			end)
		end
	else
		local idx = tonumber(index)
		if idx then
			task.spawn(function()
				self:_setLightState(groupId, idx, true)
				task.wait(duration)
				self:_setLightState(groupId, idx, false)
			end)
		end
	end
end

-- ── Private ──────────────────────────────────────────────────────────────────

function LightShowService:_setLightState(groupId: string, index: number, isOn: boolean)
	local lights = _lightGroups[groupId]
	if not lights then return end
	
	local housing = lights[index]
	if housing then
		-- Toggle visual on the specific housing
		pcall(function()
			(housing :: any).UsePartColor = isOn
		end)
	end

	-- Toggle SHARED light parts for the entire group
	local shared = _sharedParts[groupId]
	if shared then
		for _, name in { "LightPart1", "LightPart2" } do
			local container = shared[name]
			if container then
				-- Toggle any child that has an 'Enabled' property (SpotLight, PointLight, etc.)
				for _, lightObj in ipairs(container:GetChildren()) do
					pcall(function()
						(lightObj :: any).Enabled = isOn
					end)
				end
			end
		end
	end
end

return LightShowService
