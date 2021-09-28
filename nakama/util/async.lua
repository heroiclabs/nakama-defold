--[[--
Run functions asynchronously.

@module nakama.util.async
]]

local M = {}

local unpack = _G.unpack or table.unpack


--- Execute a function asynchronously as a coroutines and return the result.
-- @param fn The function to execute.
-- @param ... Function params.
-- @return The result of executing the function.
function M.async(fn, ...)
	assert(fn)
	local co = coroutine.running()
	assert(co)
	local results = nil
	local state = "RUNNING"
	fn(function(...)
		results = { ... }
		if state == "YIELDED" then
			local ok, err = coroutine.resume(co)
			if not ok then print(err) end
		else
			state = "DONE"
		end
	end, ...)
	if state == "RUNNING" then
		state = "YIELDED"
		coroutine.yield()
		state = "DONE"		-- not really needed
	end
	return unpack(results)
end


setmetatable(M, {
	__call = function(t, ...)
		return M.async(...)
	end
})


return M
