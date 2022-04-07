local inspect = require("inspect")
local curses = require("curses")

local room_size_goal = 400
local game = {
	width = tonumber(arg[1]),
	height = tonumber(arg[2]),
	seed = tonumber(arg[3]),
	room_size_goal = room_size_goal,
}

math.randomseed(tonumber(game.seed))

function node_height(node)
	return node.xy11[2] - node.xy00[2]
end

function node_width(node)
	return node.xy11[1] - node.xy00[1]
end

function node_area(node)
	local height = node_height(node)
	local width = node_width(node)
	return height * width
end

function debug_node(node)
	print("height", node_height(node), "width", node_width(node), "area", node_area(node))
	print(inspect(node))
end

-- TreeNode
-- xy00: { x, y }
-- xy11: { x, y }
-- area: number
-- children: { TreeNode, TreeNode }
local bsp_tree = {
	xy00 = { 0, 0 },
	xy11 = { tonumber(game.width) - 1, tonumber(game.height) - 1 },
	children = {},
}
bsp_tree.area = node_area(bsp_tree)
bsp_tree.height = node_height(bsp_tree)
bsp_tree.width = node_width(bsp_tree)

local rooms = { bsp_tree }

function partition(node)
	local vertical = math.random() > 0.5
	local val = vertical and node_width(node) or node_height(node)
	local margin = val / 100 * 1
	-- print(inspect({ val, margin, (val / 2) - margin, (val / 2) + margin }))
	local split = math.floor(math.random((val / 2) - margin, (val / 2) + margin))
	-- print("split", vertical and "vertically" or "horizontally", "at", split)

	local gap = 0
	local child1 = vertical
			and {
				xy00 = { node.xy00[1] + gap, node.xy00[2] + gap },
				xy11 = { node.xy11[1] - split - gap, node.xy11[2] - gap },
				children = {},
			}
		or {
			xy00 = { node.xy00[1] + gap, node.xy00[2] + gap },
			xy11 = { node.xy11[1] - gap, node.xy11[2] - split - gap },
			children = {},
		}

	child1.area = node_area(child1)

	child1.height = node_height(child1)
	child1.width = node_width(child1)
	local child2 = vertical
			and {
				xy00 = { node.xy00[1] + split + gap, node.xy00[2] + gap },
				xy11 = { node.xy11[1] - gap, node.xy11[2] - gap },
				children = {},
			}
		or {
			xy00 = { node.xy00[1] + gap, node.xy00[2] + split + gap },
			xy11 = { node.xy11[1] - gap, node.xy11[2] - gap },
			children = {},
		}
	child2.area = node_area(child2)
	child2.height = node_height(child2)
	child2.width = node_width(child2)

	-- debug_node(node)
	-- debug_node(child1)
	-- debug_node(child2)

	if node_area(child1) >= game.room_size_goal then
		partition(child1)
		table.insert(node.children, child1)
		table.insert(rooms, child1)
	end

	if node_area(child2) >= game.room_size_goal then
		partition(child2)
		table.insert(node.children, child2)
		table.insert(rooms, child2)
	end
end

partition(bsp_tree)

-- print(inspect(bsp_tree))
print(inspect(rooms))
print(#rooms)

function main()
	local stdscr = curses.initscr()
	local run = true

	while run do
		stdscr:clear()

		for x = 0, game.width do
			for y = 0, game.height do
				for i, room in ipairs(rooms) do
					local isX = (x >= room.xy00[1] or x <= room.xy11[1]) and (y == room.xy00[2] or y == room.xy11[2])
					local isY = (y >= room.xy00[2] or y <= room.xy11[2]) and (x == room.xy00[1] or x == room.xy11[1])
					local char = (isX or isY) and "#" or ""
					if char == "#" and #room.children == 0 then
						stdscr:mvaddstr(x, y, char)
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

		stdscr:refresh()
	end
	curses.endwin()
end
main()

print(inspect(game))
