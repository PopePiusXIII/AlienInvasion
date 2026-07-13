local RngCore = {}

--- Selects a random item from an array with uniform distribution.
-- @param items Array of items to choose from.
-- @return A randomly selected item, or nil if the array is empty.
function RngCore.selectRandom<T>(items: {T}): T?
	if #items == 0 then
		return nil
	end
	local index = math.random(1, #items)
	return items[index]
end

--- Selects 3 random items from an array with uniform distribution, no duplicates.
-- @param items Array of items to choose from.
-- @return An array of up to 3 randomly selected items. Returns fewer if the array has less than 3 elements.
function RngCore.selectRandom3<T>(items: {T}): {T}
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

return RngCore