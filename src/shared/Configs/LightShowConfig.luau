--!strict
--------------------------------------------------------------------------------
-- LightShowConfig.luau  (lobby/src/shared)
-- Definitions for light show sequences.
--------------------------------------------------------------------------------

export type LightStep = {
	group:     string,
	index:     number | string,
	duration:  number,
	startTime: number,
}

local LightShowConfig = {}

LightShowConfig.DEFAULT_LOOPS = 20

-- Example show for a 4-beat pattern
LightShowConfig.BasicPattern = {
	{ group = "a", index = "all", duration = 0.5, startTime = 0.0 },
	{ group = "b", index = "all", duration = 0.5, startTime = 0.5 },
	{ group = "a", index = "all", duration = 0.5, startTime = 1.0 },
	{ group = "b", index = "all", duration = 0.5, startTime = 1.5 },
}

-- Comprehensive stadium show
function LightShowConfig.GetFullShow(): {LightStep}
	local sequence = {}
	
	-- 1. All flash twice (strobe)
	for i = 0, 1 do
		table.insert(sequence, { group = "a", index = "all", duration = 0.5, startTime = 0.0 + (i * 1) })
		table.insert(sequence, { group = "b", index = "all", duration = 0.5, startTime = 0.0 + (i * 1) })
	end
	
	return sequence
end

--- Calculates the total duration of a sequence (latest endTime).
function LightShowConfig.GetSequenceDuration(sequence: {LightStep}): number
	local maxTime = 0
	for _, step in ipairs(sequence) do
		local endTime = step.startTime + step.duration
		if endTime > maxTime then
			maxTime = endTime
		end
	end
	return maxTime
end

-- Circular chase pattern
function LightShowConfig.GetCircularChase(groups: {string}, count: number, speed: number): {LightStep}
	local sequence = {}
	for i = 1, count do
		for j, groupId in ipairs(groups) do
			table.insert(sequence, {
				group     = groupId,
				index     = i,
				duration  = speed,
				startTime = ((i - 1) * #groups + (j - 1)) * speed
			})
		end
	end
	return sequence
end

--- Replicates a sequence multiple times with a fixed offset.
function LightShowConfig.GetLoopedSequence(baseSequence: {LightStep}, iterations: number, interval: number): {LightStep}
	local fullSequence = {}
	for i = 0, iterations - 1 do
		for _, step in ipairs(baseSequence) do
			table.insert(fullSequence, {
				group     = step.group,
				index     = step.index,
				duration  = step.duration,
				startTime = step.startTime + (i * interval)
			})
		end
	end
	return fullSequence
end

return LightShowConfig
