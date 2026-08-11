--!strict
local server_script_service = game:GetService("ServerScriptService")
local RngCoreTypes = require(server_script_service.common.modules.rng_core_types)

--- Selects a random item from an array with uniform distribution.
-- @param items Array of items to choose from.
-- @return A randomly selected item, or nil if the array is empty.
local function selectRandom<T>(items: {T}): T?
	if #items == 0 then
		return nil
	end
	local index = math.random(1, #items)
	return items[index]
end

--- Selects 3 random items from an array with uniform distribution, no duplicates.
-- @param items Array of items to choose from.
-- @return An array of up to 3 randomly selected items. Returns fewer if the array has less than 3 elements.
local function selectRandom3<T>(items: {T}): {T}
	local count = math.min(3, #items)
	local selected = {}
	local pool = table.clone(items)
	
	for _ = 1, count do
		local index = math.random(1, #pool)
		table.insert(selected, pool[index])
		table.remove(pool, index)
	end
	
	return selected
end


local RngCore: RngCoreTypes.RngCoreT = {
	selectRandom = selectRandom,
	selectRandom3 = selectRandom3,
}



return RngCore
