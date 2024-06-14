local M = {}

function M.now()
	return os.date("%Y-%m-%dT%H:%M:%SZ")
end

return M