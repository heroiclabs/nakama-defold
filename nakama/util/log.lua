--[[--
Nakama logging module.

@module nakama.util.log
]]


local M = {}

local function noop() end


--- Silence all logging.
function M.silent()
	M.log = noop
end


--- Print all log messages to the default system output.
function M.print()
	M.log = print
end


-- Format all log message before print to the default system output.
function M.format()
	M.log = function(fmt, ...)
		print(string.format(fmt, ...))
	end
end


--- Set a custom log function.
-- @param fn The custom log function.
function M.custom(fn)
	M.log = fn
end


M.silent()


setmetatable(M, {
	__call = function(t, ...)
		M.log(...)
	end
})


return M
