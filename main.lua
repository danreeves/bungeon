local inspect = require("inspect")
local curses = require("curses")
local stdscr = curses.initscr()

local room_size_goal = {
	width = curses.cols() / 10,
	height = curses.lines() / 5,
}
local game = {
	height = curses.lines(),
	width = curses.cols(),
	seed = 1337 * os.time(),
	room_size_goal = room_size_goal,
}
print(inspect(game))

math.randomseed(tonumber(game.seed))

-- TreeNode
-- xy: { x, y }
-- height: number
-- width: number
-- children: { TreeNode, TreeNode }
local bsp_tree = {
	xy = { 1, 1 },
	height = game.height - 2,
	width = game.width - 2,
	children = {},
}

local rooms = { bsp_tree }

local function partition(node, verticalOverride)
	local vertical = verticalOverride ~= nil and verticalOverride or math.random() > 0.5
	local val = vertical and node.width or node.height
	local margin = val / 100 * 10
	local split = math.floor(math.random((val / 2) - margin, (val / 2) + margin))

	local gap = 0
	local child1 = vertical
			and {
				xy = { node.xy[1], node.xy[2] },
				width = split - gap,
				height = node.height,
				children = {},
			}
		or {
			xy = { node.xy[1], node.xy[2] },
			width = node.width,
			height = split - gap,
			children = {},
		}

	local child2 = vertical
			and {
				xy = { node.xy[1] + split + gap, node.xy[2] },
				width = node.width - (split + gap),
				height = node.height,
				children = {},
			}
		or {
			xy = { node.xy[1], node.xy[2] + split + gap },
			width = node.width,
			height = node.height - (split + gap),
			children = {},
		}

	if
		child1.width >= game.room_size_goal.width
		and child1.height >= game.room_size_goal.height
		and child2.width >= game.room_size_goal.width
		and child2.height >= game.room_size_goal.height
	then
		partition(child1)
		table.insert(node.children, child1)
		table.insert(rooms, child1)

		partition(child2)
		table.insert(node.children, child2)
		table.insert(rooms, child2)
	elseif verticalOverride == nil then
		partition(node, not vertical)
	end
end

partition(bsp_tree)

local leafs = {}

for _, room in ipairs(rooms) do
	if #room.children == 0 then
		table.insert(leafs, room)
	end
end

print(#leafs)
-- print(inspect(leafs))

local draw_room = 1

local function main()
	local run = true

	while run do
		stdscr:clear()

		for x = 0, game.width do
			for y = 0, game.height do
				local room_index = 0
				for _, room in ipairs(leafs) do
					room_index = room_index + 1
					-- if room_index == draw_room then
					-- print(inspect(room))
					local isWallX = (x >= room.xy[1] and x <= room.xy[1] + room.width - 1)
						and (y == room.xy[2] or y == room.xy[2] + room.height - 1)
					local isWallY = (y >= room.xy[2] and y <= room.xy[2] + room.height - 1)
						and (x == room.xy[1] or x == room.xy[1] + room.width - 1)
					local isFloor = (x > room.xy[1] and x < room.xy[1] + room.width - 1)
						and (y > room.xy[2] and y < room.xy[2] + room.height - 1)
					local char = (isWallX or isWallY) and "#" or ""
					if isFloor then
						char = "." --string.char(room_index + 97) --"."
					end
					if (x == 0 or x == game.width - 1) and (y == 0 or y == game.height - 1) then
						char = "x"
					end
					if char ~= "" then
						stdscr:mvaddstr(y, x, char)
					end
					-- end
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

		if c == "a" then
			draw_room = draw_room + 1
		end

		stdscr:refresh()
	end
	curses.endwin()
end
main()
