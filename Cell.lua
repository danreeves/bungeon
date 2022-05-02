local class = require("./vendor/oops")

local Cell = class({
	__init = function(self, x, y)
		self.x = x
		self.y = y
		self.type = "none"
		self.char_map = {
			none = " ",
			wall = "#",
			floor = ".",
			door = "+",
			path = "@",
			spawn = "&",
			goal = "$",
		}
	end,

	draw = function(self)
		local char = self.char_map[self.type] or " "
		return char
	end,
})

return Cell
