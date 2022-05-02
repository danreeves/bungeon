local class = require("oops")
local contains = require("./contains")

local tn_count = 0
local TreeNode = class("TreeNode")({
	__init = function(self, x, y, height, width, parent)
		self.x = x or 0
		self.y = y or 0
		self.height = height or 0
		self.width = width or 0
		self.children = {}
		self.room = nil
		self.parent = parent
		self.depth = parent and parent.depth + 1 or 0
		self.connections = {}

		tn_count = tn_count + 1
		self._id = tn_count
	end,

	to_string = function(self)
		return "TreeNode:" .. tostring(self._id)
	end,

	add_child = function(self, child)
		table.insert(self.children, child)
	end,

	is_wall = function(self, x, y)
		local isWallX = (x >= self.x and x <= self.x + self.width - 1)
			and (y == self.y or y == self.y + self.height - 1)
		local isWallY = (y >= self.y and y <= self.y + self.height - 1)
			and (x == self.x or x == self.x + self.width - 1)
		return isWallX or isWallY
	end,

	is_inside = function(self, x, y)
		return (x >= self.x and x <= self.x + self.width - 1) and (y >= self.y and y <= self.y + self.height - 1)
	end,

	is_around = function(self, x, y, margin)
		return (x >= self.x - margin and x <= self.x + self.width - 1 + margin)
			and (y >= self.y - margin and y <= self.y + self.height - 1 + margin)
	end,

	get_center = function(self)
		local x = math.floor((self.x + (self.width / 2)) + 0.5)
		local y = math.floor((self.y + (self.height / 2)) + 0.5)
		return { x = x, y = y }
	end,

	random_point_inside = function(self, padding)
		local x = math.random(self.x + 1 + padding, self.x + (self.width - 1) - padding)
		local y = math.random(self.y + 1 + padding, self.y + (self.height - 1) - padding)
		return { x = x, y = y }
	end,

	add_connection = function(self, room)
		table.insert(self.connections, room)
		table.insert(room.connections, self)
	end,

	is_connected = function(self, room)
		return contains(self.connections, room)
	end,

	get_sibling = function(self)
		if self.parent then
			for _, child in ipairs(self.parent.children) do
				if child ~= self then
					return child
				end
			end
		end
	end,

	get_rooms_below = function(self)
		local rooms = {}
		for _, child in ipairs(self.children) do
			if child.room then
				table.insert(rooms, child.room)
			else
				local child_rooms = child:get_rooms_below()
				for _, r in ipairs(child_rooms) do
					table.insert(rooms, r)
				end
			end
		end
		return rooms
	end,
})

return TreeNode
