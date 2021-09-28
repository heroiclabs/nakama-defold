--[[--
Create and check Nakama sessions.

@module nakama.session
]]


local b64 = require "nakama.util.b64"
local json = require "nakama.util.json"
local log = require "nakama.util.log"

local M = {}

local JWT_TOKEN = "^(.-)%.(.-)%.(.-)$"


--- Check whether a Nakama session has expired or not.
-- @param session The session object created with session.create.
-- @return A boolean if the session has expired or not.
function M.expired(session)
	assert(session and session.expires, "You must provide a session")
	return os.time() > session.expires
end


--- Create a session object with the given data and included token.
-- @param data A data table containing a "token" attribute.
-- @return The session object.
function M.create(data)
	local token = data.token
	assert(token, "You must provide a token")

	local p1, p2, p3 = token:match(JWT_TOKEN)
	assert(p1 and p2 and p3, "jwt is not valid")

	log(p2)
	local decoded = json.decode(b64.decode(p2))
	local session = {
		token = token,
		created = os.time(),
		expires = decoded.exp,
		username = decoded.usn,
		user_id = decoded.uid,
		vars = decoded.vrs
	}
	return session
end

return M
