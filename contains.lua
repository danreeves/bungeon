-- Moved out of utils to fix a circular dependency
local function contains(list, x)
	for _, v in pairs(list) do
		if v == x then
			return true
		end
	end
	return false
end

return contains
