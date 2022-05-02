local times = {}

local function start(label)
	times[label] = os.clock()
end

local function stop(label)
	local time = os.clock() - times[label]
	io.write(label, " took ", time, "s\n\r")
end

return {
	start = start,
	stop = stop,
}
