--[[--
Create and check Nakama sessions.

@module nakama.session
]]


local b64 = require "nakama.util.b64"
local json = require "nakama.util.json"
local log = require "nakama.util.log"

local M = {}

local JWT_TOKEN = "^(.-)%.(.-)%.(.-)$"


--- Check whether a Nakama session token is about to expire (within 24 hours)
-- @param session The session object created with session.create().
-- @return A boolean if the token is about to expire or not.
function M.is_token_expired_soon(session)
	assert(session and session.expires, "You must provide a session")
	return os.time() + (60 * 60 * 24) > session.expires
end

--- Check whether a Nakama session token has expired or not.
-- @param session The session object created with session.create().
-- @return A boolean if the token has expired or not.
function M.is_token_expired(session)
	assert(session and session.expires, "You must provide a session")
	return os.time() > session.expires
end
-- for backwards compatibility
function M.expired(session)
	return M.is_token_expired(session)
end

--- Check whether a Nakama session refresh token has expired or not.
-- @param session The session object created with session.create().
-- @return A boolean if the refresh token has expired or not.
function M.is_refresh_token_expired(session)
	assert(session, "You must provide a session")
	if not session.refresh_token_expires then
		return true
	end
	return os.time() > session.refresh_token_expires
end

--- Decode JWT token
-- @param token base 64 encoded JWT token
-- @return decoded token table
local function decode_token(token)
	local p1, p2, p3 = token:match(JWT_TOKEN)
	assert(p1 and p2 and p3, "jwt is not valid")
	return json.decode(b64.decode(p2))
end

--- Create a session object with the given data and included token.
-- @param data A data table containing a "token", "refresh_token" and other additional information.
-- @return The session object.
function M.create(data)
	assert(data.token, "You must provide a token")

	local session = {
		created = os.time()
	}

	local decoded_token = decode_token(data.token)
	session.token = data.token
	session.expires = decoded_token.exp
	session.username = decoded_token.usn
	session.user_id = decoded_token.uid
	session.vars = decoded_token.vrs

	if data.refresh_token then
		local decoded_refresh_token = decode_token(data.refresh_token)
		session.refresh_token = data.refresh_token
		session.refresh_token_expires = decoded_refresh_token.exp
		session.refresh_token_username = decoded_refresh_token.usn
		session.refresh_token_user_id = decoded_refresh_token.uid
		session.refresh_token_vars = decoded_refresh_token.vrs
	end
	return session
end


local function get_session_save_filename()
	local project_tite = sys.get_config("project.title")
	local application_id = b64.encode(project_tite)
	return sys.get_save_file(application_id, "nakama.session")
end

--- Store a session on disk
-- @param session The session to store
-- @return sucess
function M.store(session)
	assert(session)
	local filename = get_session_save_filename()
	return sys.save(filename, session)
end

--- Restore a session previously stored using session.store()
-- @return The session or nil if no session has been stored
function M.restore()
	local filename = get_session_save_filename()
	local session = sys.load(filename)
	if not session.token then
		return nil
	end
	return session
end

return M
