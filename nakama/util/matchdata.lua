local b64 = require "nakama.util.b64"
local json = require "nakama.util.json"

local M = {}

--- Encode a table into JSON wrapped in Base64
-- @param data Table to encode
-- @return base64-encoded string
function M.encode(data)
	assert(data, "You must provide a table to encode")
	local jsonned = json.encode(data)
	return b64.encode(jsonned)
end

--- Decode a table from Base64-wrapped JSON
-- @param base64 string
-- @return data table
function M.decode(data)
	assert(data, "You must provide a base64-string to decode")
	local jsonned = b64.decode(data)
	return json.decode(jsonned)
end

return M
