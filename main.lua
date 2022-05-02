local utils = require("./utils")
local TreeNode = require("./TreeNode")
local Cell = require("./Cell")
local profile = require("./profile")

local room_size_goal = {
	width = 20,
	height = 8,
	min_size = 8,
	padding = 1,
}
local game = {
	height = 35,
	width = 160,
	seed = 1337 * os.time(),
	room_size_goal = room_size_goal,
}

io.write("Seed: ", tostring(game.seed), "\n\r")
math.randomseed(tonumber(game.seed))

-- Start with a rectangle the size of the game settings
local bsp_tree = TreeNode(1, 1, game.height - 1, game.width - 1)

-- Create a binary space partition to put rooms into -- guarantees no overlaps
profile.start("partitioning")
utils.make_partition(game, bsp_tree)
profile.stop("partitioning")

-- Find the leaf nodes and put random sized rooms into them
-- This would be a good point to insert prefab rooms
profile.start("creating rooms")
local leafs = utils.find_leafs(bsp_tree)
for _, leaf in ipairs(leafs) do
	local height = math.random(game.room_size_goal.min_size, leaf.height)
	local width = math.random(game.room_size_goal.min_size, leaf.width)
	local x = math.random(leaf.x, leaf.x + (leaf.width - width))
	local y = math.random(leaf.y, leaf.y + (leaf.height - height))
	local room = TreeNode(x, y, height, width)
	leaf.room = room
end
profile.stop("creating rooms")

-- Create a grid of cells from the rooms
profile.start("creating grid")
local flat_cells = {}
local map = {}
for y = 1, game.height do
	for x = 1, game.width do
		local cell = Cell(x, y)
		for _, room in ipairs(bsp_tree:get_rooms_below()) do
			if room:is_inside(x, y) then
				cell.type = "floor"
			end
			if room:is_wall(x, y) then
				cell.type = "wall"
			end
		end
		table.insert(flat_cells, cell)
		if map[y] == nil then
			map[y] = {}
		end
		if map[y][x] == nil then
			map[y][x] = {}
		end
		map[y][x] = cell
	end
end
profile.stop("creating grid")

-- Connect the rooms from the bottom of the BSP tree up
-- This guarantees all rooms are connected
profile.start("connecting rooms")
utils.depth_first_connect(game, bsp_tree, map)
profile.stop("connecting rooms")

-- Find the longest disance between two rooms and set them
-- as start and end points
-- TODO: This gets SLOW with more rooms,
-- investigate optimisations or other algorithms
profile.start("finding start and end")
utils.get_start_and_end(game, bsp_tree, map)
profile.stop("finding start and end")

-- Loop over the cells and print them out
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
