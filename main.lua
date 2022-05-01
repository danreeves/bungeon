local class = require("oops")
local luastar = require("./lua-star")

local function contains(list, x)
	for _, v in pairs(list) do
		if v == x then
			return true
		end
	end
	return false
end

local room_size_goal = {
	width = 20,
	height = 8,
	min_size = 8,
	padding = 1,
}
local game = {
	height = 35,
	width = 160,
	seed = 2207985323544, --1337 * os.time(),
	room_size_goal = room_size_goal,
}

io.write("Seed: ", tostring(game.seed), "\n\r")
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

local bsp_tree = TreeNode(1, 1, game.height - 1, game.width - 1)

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
		}
	end,

	draw = function(self)
		local char = self.char_map[self.type] or " "
		return char
	end,
})

-- Convert to cells in grid
local flat_cells = {}
local grid = {}
for y = 1, game.height do
	for x = 1, game.width do
		local cell = Cell(x, y)
		for _, room in ipairs(rooms) do
			if room:is_inside(x, y) then
				cell.type = "floor"
			end
			if room:is_wall(x, y) then
				cell.type = "wall"
			end
		end
		table.insert(flat_cells, cell)
		if grid[y] == nil then
			grid[y] = {}
		end
		if grid[y][x] == nil then
			grid[y][x] = {}
		end
		grid[y][x] = cell
	end
end

local function p(...)
	io.write(...)
	io.write("\n\r")
end

local function distance(x1, y1, x2, y2)
	return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

local function get_closest_room(list, room, is_valid_room)
	local is_valid_room_fn = is_valid_room or function()
		return true
	end
	local closest = nil
	local closest_dist = math.huge
	local c1 = room:get_center()
	for _, r in ipairs(list) do
		if r ~= room and is_valid_room_fn(r) then
			local c2 = r:get_center()
			local dist = distance(c1.x, c1.y, c2.x, c2.y)
			-- TODO check all four corners instead of centers?
			if dist < closest_dist then
				closest = r
				closest_dist = dist
			end
		end
	end
	return closest, closest_dist
end

local function get_grid_cell(x, y, grid)
	local row = grid[y]
	if row then
		local col = row[x]
		return col
	end
end

local function on_grid_cell(x, y, grid, func)
	local cell = get_grid_cell(x, y, grid)
	if cell then
		func(cell)
	end
end

local function if_none_wall(cell)
	if cell.type == "none" then
		cell.type = "wall"
	end
end

local function connect_rooms(r1, r2, grid)
	local start = r1:random_point_inside(2)
	local goal = r2:random_point_inside(2)

	local function is_valid_node(x, y)
		-- Not along edges
		if x == 1 or x == game.width - 1 or y == 1 or y == game.height - 1 then
			return false
		end

		-- No crossing paths
		local cell = grid[y][x]
		if cell.type == "floor" and not r1:is_inside(x, y) and not r2:is_inside(x, y) then
			-- return false
		end

		-- Not through other rooms
		if cell.type == "wall" and not r1:is_inside(x, y) and not r2:is_inside(x, y) then
			return false
		end

		return true
	end

	local path = luastar:find(game.width, game.height, start, goal, is_valid_node, true, true)
	if path then
		r1:add_connection(r2)
		for _, node in ipairs(path) do
			local c = grid[node.y][node.x]
			if c.type == "wall" then
				c.maybe_door = true
			end
			c.type = "floor"
		end
		for _, node in ipairs(path) do
			on_grid_cell(node.x, node.y - 1, grid, if_none_wall) -- above
			on_grid_cell(node.x, node.y + 1, grid, if_none_wall) -- below
			on_grid_cell(node.x - 1, node.y, grid, if_none_wall) -- left
			on_grid_cell(node.x + 1, node.y, grid, if_none_wall) -- right
			on_grid_cell(node.x + 1, node.y + 1, grid, if_none_wall) -- bottom right
			on_grid_cell(node.x - 1, node.y + 1, grid, if_none_wall) -- bottom left
			on_grid_cell(node.x + 1, node.y - 1, grid, if_none_wall) -- top right
			on_grid_cell(node.x - 1, node.y - 1, grid, if_none_wall) -- top left

			local c = grid[node.y][node.x]
			local l = get_grid_cell(node.x - 1, node.y, grid)
			local r = get_grid_cell(node.x + 1, node.y, grid)
			local a = get_grid_cell(node.x, node.y - 1, grid)
			local b = get_grid_cell(node.x, node.y + 1, grid)

			local surrounding_floors = 0
			for _, surrounding_cell in ipairs({ l, r, a, b }) do
				if surrounding_cell.type == "floor" then
					surrounding_floors = surrounding_floors + 1
				end
			end

			if
				c.maybe_door
				and surrounding_floors == 2
				and (
					(l and l.type == "floor" and r and r.type == "floor")
					or (a and a.type == "floor" and b and b.type == "floor")
				)
			then
				c.type = "door"
			end
		end
	end
end

local function depth_first_connect(node)
	for _, child in ipairs(node.children) do
		depth_first_connect(child)
	end
	local sibling = node:get_sibling()
	if sibling then
		if node.room then
			if sibling.room then
				if not node.room:is_connected(sibling.room) then
					connect_rooms(node.room, sibling.room, grid)
				end
			else
				local sibling_rooms = sibling:get_rooms_below()
				local closest_room = get_closest_room(sibling_rooms, node.room, function(r)
					return not r:is_connected(node.room)
				end)
				if closest_room then
					connect_rooms(node.room, closest_room, grid)
				end
			end
		else
			local node_rooms = node:get_rooms_below()
			if sibling.room then
				local closest_room = get_closest_room(node_rooms, sibling.room, function(r)
					return not r:is_connected(sibling.room)
				end)
				if closest_room then
					connect_rooms(sibling.room, closest_room, grid)
				end
			else
				local sibling_rooms = sibling:get_rooms_below()
				local shortest_distance = math.huge
				local closest_rooms = {}

				for _, r1 in ipairs(node_rooms) do
					for _, r2 in ipairs(sibling_rooms) do
						local c1 = r1:get_center()
						local c2 = r2:get_center()
						local dist = distance(c1.x, c1.y, c2.x, c2.y)
						if dist < shortest_distance then
							shortest_distance = dist
							closest_rooms = { r1, r2 }
						end
					end
				end
				if #closest_rooms == 2 and not closest_rooms[1]:is_connected(closest_rooms[2]) then
					connect_rooms(closest_rooms[1], closest_rooms[2], grid)
				end
			end
		end
	end
end

depth_first_connect(bsp_tree)

local function print_cells()
	io.write("\r")
	for index, cell in ipairs(flat_cells) do
		io.write(cell:draw())
		if index % game.width == 0 then
			io.write("\n\r")
		end
	end
end
print_cells()
