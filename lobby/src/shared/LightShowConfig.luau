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
		table.insert(sequence, { group = "a", index = "all", duration = 0.1, startTime = 0.0 + (i * 0.2) })
		table.insert(sequence, { group = "b", index = "all", duration = 0.1, startTime = 0.0 + (i * 0.2) })
	end

	-- 2. Wave/Chase from 1 to 18
	for i = 1, 18 do
		local offset = 0.5 + (i * 0.05)
		table.insert(sequence, { group = "a", index = i, duration = 0.1, startTime = offset })
		table.insert(sequence, { group = "b", index = i, duration = 0.1, startTime = offset })
	end
	
	-- 3. Alternating sections
	for i = 0, 7 do
		local offset = 2.0 + (i * 0.25)
		table.insert(sequence, { group = (i % 2 == 0) and "a" or "b", index = "all", duration = 0.2, startTime = offset })
	end
	
	return sequence
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
