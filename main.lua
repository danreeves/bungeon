local inspect = require("inspect")
local class = require("oops")
local curses = require("curses")
local stdscr = curses.initscr()

local function contains(list, x)
	for _, v in pairs(list) do
		if v == x then
			return true
		end
	end
	return false
end

local function map(list, fn)
	local l = {}
	for _, v in ipairs(list) do
		table.insert(l, fn(v))
	end
	return l
end

local room_size_goal = {
	width = 20,
	height = 8,
	min_size = 8,
	padding = 1,
}
local game = {
	height = curses.lines(),
	width = curses.cols(),
	seed = 1337 * os.time(),
	room_size_goal = room_size_goal,
}

math.randomseed(tonumber(game.seed))

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
		return (x > self.x and x < self.x + self.width - 1) and (y > self.y and y < self.y + self.height - 1)
	end,

	get_siblings = function(self)
		if self.parent == nil then
			return {}
		end
		-- siblings including self
		return self.parent.children
	end,

	get_sibling_rooms = function(self)
		local siblings = self:get_siblings()
		local rooms = {}
		for _, sibling in ipairs(siblings) do
			table.insert(rooms, sibling.room)
		end
		return rooms
	end,
})

local bsp_tree = TreeNode(0, 0, game.height - 0, game.width - 0)

local function make_partition(node, verticalOverride)
	local vertical = verticalOverride ~= nil and verticalOverride or math.random() > 0.5
	local val = vertical and node.width or node.height
	local margin = val / 100 * 10 -- 10% of the height or width
	local split = math.floor(math.random((val / 2) - margin, (val / 2) + margin)) -- split roughly halfway, plus or minus the 10% margin
	local gap = game.room_size_goal.padding

	local child1 = vertical and TreeNode(node.x, node.y, node.height, split - gap, node)
		or TreeNode(node.x, node.y, split - gap, node.width, node)
	local child2 = vertical and TreeNode(node.x + split + gap, node.y, node.height, node.width - (split + gap), node)
		or TreeNode(node.x, node.y + split + gap, node.height - (split + gap), node.width, node)

	if
		child1.width >= game.room_size_goal.width
		and child1.height >= game.room_size_goal.height
		and child2.width >= game.room_size_goal.width
		and child2.height >= game.room_size_goal.height
	then
		make_partition(child1)
		node:add_child(child1)

		make_partition(child2)
		node:add_child(child2)
	elseif verticalOverride == nil then
		-- If the halfs are too small, try splitting in the other orientation
		make_partition(node, not vertical)
	end
end

make_partition(bsp_tree)

local function find_leafs(node, list)
	local l = list ~= nil and list or {}
	if #node.children == 0 then
		table.insert(l, node)
	else
		for _, child in ipairs(node.children) do
			find_leafs(child, l)
		end
	end
	return l
end

local leafs = find_leafs(bsp_tree)

local rooms = {}

for _, leaf in ipairs(leafs) do
	local height = math.random(game.room_size_goal.min_size, leaf.height)
	local width = math.random(game.room_size_goal.min_size, leaf.width)
	local x = math.random(leaf.x, leaf.x + (leaf.width - width))
	local y = math.random(leaf.y, leaf.y + (leaf.height - height))
	local room = TreeNode(x, y, height, width)
	leaf.room = room
	table.insert(rooms, room)
end

local done = {}

for _, leaf in ipairs(leafs) do
	local parent = leaf.parent
	if not contains(done, parent) then
		local rooms_in_parent = leaf:get_sibling_rooms()
		print(
			"joining",
			table.concat(
				map(rooms_in_parent, function(r)
					return r:to_string()
				end),
				", "
			),
			"\r"
		)
		table.insert(done, parent)
	end
end

local function draw()
	local nodes = rooms
	local run = true

	while run do
		stdscr:clear()

		for x = 0, game.width do
			for y = 0, game.height do
				for _, room in ipairs(nodes) do
					local char = room:is_wall(x, y) and "#" or ""
					if room:is_inside(x, y) then
						char = string.char(_ + 96) --"."
					end
					if char ~= "" then
						stdscr:mvaddstr(y, x, char)
					end
				end
			end
		end

		local c = stdscr:getch()
		if c < 256 then
			c = string.char(c)
		end
		if c == "q" then
			run = false
		end
		if c == "l" then
			nodes = leafs
		end
		if c == "r" then
			nodes = rooms
		end

		stdscr:refresh()
	end
	curses.endwin()
end

-- draw()
