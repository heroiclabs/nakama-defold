local M = {}

local function noop() end

function M.silent()
	M.log = noop
end

function M.print()
	M.log = print
end

function M.format()
	M.log = function(fmt, ...)
		print(string.format(fmt, ...))
	end
end

function M.custom(fn)
	M.log = fn
end

M.log = M.silent()

setmetatable(M, {
	__call = function(t, ...)
		M.log(...)
	end
})

return M
