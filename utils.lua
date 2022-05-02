local TreeNode = require("./TreeNode")
local luastar = require("./lua-star")
local contains = require("./contains")

local function make_partition(game, node, verticalOverride)
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
		make_partition(game, child1)
		node:add_child(child1)

		make_partition(game, child2)
		node:add_child(child2)
	elseif verticalOverride == nil then
		-- If the halfs are too small, try splitting in the other orientation
		make_partition(game, node, not vertical)
	end
end

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

local function connect_rooms(game, r1, r2, grid)
	local start = r1:random_point_inside(2)
	local goal = r2:random_point_inside(2)

	local function is_valid_node(x, y)
		-- Not along edges
		if x == 1 or x == game.width - 1 or y == 1 or y == game.height - 1 then
			return false
		end

		local cell = grid[y][x]

		-- TODO: Causes unconnected rooms, maybe this isn't worth it
		-- No crossing paths
		-- if cell.type == "floor" and not r1:is_inside(x, y) and not r2:is_inside(x, y) then
		-- return false
		-- end

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

local function depth_first_connect(game, node, grid)
	for _, child in ipairs(node.children) do
		depth_first_connect(game, child, grid)
	end
	local sibling = node:get_sibling()
	if sibling then
		if node.room then
			if sibling.room then
				if not node.room:is_connected(sibling.room) then
					connect_rooms(game, node.room, sibling.room, grid)
				end
			else
				local sibling_rooms = sibling:get_rooms_below()
				local closest_room = get_closest_room(sibling_rooms, node.room, function(r)
					return not r:is_connected(node.room)
				end)
				if closest_room then
					connect_rooms(game, node.room, closest_room, grid)
				end
			end
		else
			local node_rooms = node:get_rooms_below()
			if sibling.room then
				local closest_room = get_closest_room(node_rooms, sibling.room, function(r)
					return not r:is_connected(sibling.room)
				end)
				if closest_room then
					connect_rooms(game, sibling.room, closest_room, grid)
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
					connect_rooms(game, closest_rooms[1], closest_rooms[2], grid)
				end
			end
		end
	end
end

local function get_start_and_end(game, tree, grid)
	local start_time = os.time()
	local rooms = tree:get_rooms_below()
	local longest_path = nil
	local start_and_end = {}
	for _, r1 in ipairs(rooms) do
		for _, r2 in ipairs(rooms) do
			if r1 ~= r2 then
				local c1 = r1:get_center()
				local c2 = r2:get_center()
				local function is_valid_node(x, y)
					local cell = grid[y][x]
					if cell.type == "floor" or cell.type == "door" then
						return true
					end
					return false
				end
				local path = luastar:find(game.width, game.height, c1, c2, is_valid_node, true, false)
				if longest_path == nil or (path and #path > #longest_path) then
					longest_path = path
					start_and_end = { r1, r2 }
				end
			end
			if (os.time() - start_time) > 2 then
				break
			end
		end
		if (os.time() - start_time) > 2 then
			break
		end
	end

	-- DEBUG draw longest path
	-- for _, node in ipairs(longest_path) do
	--     grid[node.y][node.x].type = "path"
	-- end

	local node1 = longest_path[1]
	grid[node1.y][node1.x].type = "spawn"
	local node2 = longest_path[#longest_path]
	grid[node2.y][node2.x].type = "goal"

	return start_and_end[1], start_and_end[2]
end
return {
	contains = contains,
	make_partition = make_partition,
	find_leafs = find_leafs,
	distance = distance,
	get_closest_room = get_closest_room,
	depth_first_connect = depth_first_connect,
	get_start_and_end = get_start_and_end,
}
