local sides = require("sides")
local computer = require("computer")
local event = require("event")

local utils = {}

-- checks if element already exists in a table
function utils.hasValue(tab, value)
	for index, element in ipairs(tab) do
		if element == value then
			return true
		end
	end
	for k, v in pairs(tab) do
		if v == value then
			return true
		end
	end
	return false
end

function utils.hasKey(tab, key)
	for k, v in pairs(tab) do
		if k == key then
			return true
		end
	end
	return false
end

function utils.keys(tab)
	local ks = {}
	for k, v in pairs(tab) do
		table.insert(ks, k)
	end
	return ks
end

function utils.values(tab)
	local vs = {}
	for k, v in pairs(tab) do
		table.insert(vs, v)
	end
	return vs
end

function utils.findIndex(tab, value)
	for i, v in ipairs(tab) do
		if v == value then
			return i
		end
	end
end

--[[ measures how much time execution of a function took, returns
function return value, real execution time and cpu execution time,
and additionally prints execution times --]]
function utils.timeIt(doPrint, func, ...)
	local args = {...}
	if type(doPrint) == "function" then
		table.insert(args, 1, func)
		func = doPrint
	end
	local realBefore, cpuBefore = computer.uptime(), os.clock()
	local returnVal = func(table.unpack(args))
	local realAfter, cpuAfter = computer.uptime(), os.clock()

	local realDiff = realAfter - realBefore
	local cpuDiff = cpuAfter - cpuBefore

	if doPrint then
		print(string.format('real%5dm%.3fs', math.floor(realDiff/60), realDiff%60))
		print(string.format('cpu %5dm%.3fs', math.floor(cpuDiff/60), cpuDiff%60))
	end

	return returnVal, realDiff, cpuDiff
end

--[[ measures how much energy execution of a function took, returns
function return value, energy difference, and additionally prints
execution times --]]
function utils.energyIt(doPrint, func, ...)
	local args = {...}
	if type(doPrint) == "function" then
		table.insert(args, 1, func)
		func = doPrint
	end
	local before = computer.energy()
	local returnVal = func(table.unpack(args))
	local after = computer.energy()

	local diff = after - before
	if doPrint then
		print(string.format("Energy difference: %f", diff))
	end

	return returnVal, diff
end

--[[ force Lua garbage collector to run, credits to Akuukis and Sangar,
check https://oc.cil.li/topic/243-memory-management/ --]]
function utils.freeMemory()
	local result = 0
	for i = 1, 10 do
	  result = math.max(result, computer.freeMemory())
	  os.sleep(0)
	end
	return result
end

-- waits for a keypress
function utils.waitForInput()
	event.pull("key_down")
end

-- checks if object is an instance of class by comparing metatables
function utils.isInstance(instance, class)
	return getmetatable(instance) == class
end

--[[ deepcopy a table, credits to tylerneylon,
check https://gist.github.com/tylerneylon/81333721109155b2d244 --]]
function utils.deepCopy(obj, seen)
	-- Handle non-tables and previously-seen tables.
	if type(obj) ~= 'table' then
		return obj
	end
	if seen and seen[obj] then
		return seen[obj]
	end

	-- New table; mark it as seen an copy recursively.
	local s = seen or {}
	local res = {}
	s[obj] = res
	for k, v in next, obj do
		res[utils.deepCopy(k, s)] = utils.deepCopy(v, s)
	end
	setmetatable(res, getmetatable(obj))
	return res
end

function utils.shallowCompare(obj1, obj2, ignoreKeys)
	ignoreKeys = ignoreKeys or {}
	for k, v in pairs(obj1) do
		if not utils.hasValue(ignoreKeys, k) and (obj2[k] == nil or obj2[k] ~= v) then
			return false
		end
	end
	for i, v in ipairs(obj1) do
		if obj2[i] == nil or obj2[i] ~= v then
			return false
		end
	end
	return true
end

return utils