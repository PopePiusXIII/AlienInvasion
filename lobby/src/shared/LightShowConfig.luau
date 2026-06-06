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
	{ group = "A", index = "all", duration = 0.5, startTime = 0.0 },
	{ group = "B", index = "all", duration = 0.5, startTime = 1.0 },
}

-- Comprehensive stadium show
function LightShowConfig.GetFullShow(): {LightStep}
	local sequence = {}
	
	-- 1. All flash twice (strobe)
	table.insert(sequence, { group = "A", index = "all", duration = 0.2, startTime = 0.0 })
	table.insert(sequence, { group = "B", index = "all", duration = 0.2, startTime = 0.0 })
	table.insert(sequence, { group = "A", index = "all", duration = 0.2, startTime = 0.5 })
	table.insert(sequence, { group = "B", index = "all", duration = 0.2, startTime = 0.5 })

	-- 2. Wave/Chase from 1 to 18
	for i = 1, 18 do
		table.insert(sequence, { group = "A", index = i, duration = 0.1, startTime = 1.0 + (i * 0.05) })
		table.insert(sequence, { group = "B", index = i, duration = 0.1, startTime = 1.0 + (i * 0.05) })
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
