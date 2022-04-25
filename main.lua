local inspect = require("inspect")
local curses = require("curses")
local stdscr = curses.initscr()

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

-- TreeNode
-- x: 0
-- y: 0
-- height: number
-- width: number
-- children: { TreeNode, TreeNode }
local bsp_tree = {
	x = 0,
	y = 0,
	height = game.height - 0,
	width = game.width - 0,
	children = {},
}

local function make_partition(node, verticalOverride)
	local vertical = verticalOverride ~= nil and verticalOverride or math.random() > 0.5
	local val = vertical and node.width or node.height
	local margin = val / 100 * 10 -- 10% of the height or width
	local split = math.floor(math.random((val / 2) - margin, (val / 2) + margin)) -- split roughly halfway, plus or minus the 10% margin

	local gap = game.room_size_goal.padding
	local child1 = vertical
			and {
				x = node.x,
				y = node.y,
				width = split - gap,
				height = node.height,
				children = {},
				rooms = {},
				parent = node,
			}
		or {
			x = node.x,
			y = node.y,
			width = node.width,
			height = split - gap,
			children = {},
			rooms = {},
			parent = node,
		}

	local child2 = vertical
			and {
				x = node.x + split + gap,
				y = node.y,
				width = node.width - (split + gap),
				height = node.height,
				children = {},
				rooms = {},
				parent = node,
			}
		or {
			x = node.x,
			y = node.y + split + gap,
			width = node.width,
			height = node.height - (split + gap),
			children = {},
			rooms = {},
			parent = node,
		}

	if
		child1.width >= game.room_size_goal.width
		and child1.height >= game.room_size_goal.height
		and child2.width >= game.room_size_goal.width
		and child2.height >= game.room_size_goal.height
	then
		make_partition(child1)
		table.insert(node.children, child1)

		make_partition(child2)
		table.insert(node.children, child2)
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
	local room = {
		x = x,
		y = y,
		height = height,
		width = width,
	}
	table.insert(leaf.rooms, room)
	table.insert(rooms, room)
end

local function draw()
	local nodes = rooms
	local run = true

	while run do
		stdscr:clear()

		for x = 0, game.width do
			for y = 0, game.height do
				for _, room in ipairs(nodes) do
					local isWallX = (x >= room.x and x <= room.x + room.width - 1)
						and (y == room.y or y == room.y + room.height - 1)
					local isWallY = (y >= room.y and y <= room.y + room.height - 1)
						and (x == room.x or x == room.x + room.width - 1)
					local isFloor = (x > room.x and x < room.x + room.width - 1)
						and (y > room.y and y < room.y + room.height - 1)
					local char = (isWallX or isWallY) and "#" or ""
					if isFloor then
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

draw()
