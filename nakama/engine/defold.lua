--[[--
 Nakama defold integration.

 @module nakama.engine.defold
]]

local log = require "nakama.util.log"
local b64 = require "nakama.util.b64"
local uri = require "nakama.util.uri"
local json = require "nakama.util.json"
local uuid = require "nakama.util.uuid"

b64.encode = _G.crypt and _G.crypt.encode_base64 or b64.encode
b64.decode = _G.crypt and _G.crypt.decode_base64 or b64.decode

local b64_encode = b64.encode
local b64_decode = b64.decode
local uri_encode_component = uri.encode_component
local uri_decode_component = uri.decode_component
local uri_encode = uri.encode
local uri_decode = uri.decode

uuid.seed()

-- replace Lua based json.encode and decode with native Defold functions
-- native json.encode function was added in Defold 1.3.7
-- native json.decode function has been included in Defold "forever"
json.encode = _G.json and _G.json.encode or json.encode
json.decode = _G.json and _G.json.decode or json.decode

local M = {}

--- Get the device's mac address.
-- @return The mac address string.
local function get_mac_address()
	local ifaddrs = sys.get_ifaddrs()
	for _,interface in ipairs(ifaddrs) do
		if interface.mac then
			return interface.mac
		end
	end
	return nil
end

--- Returns a UUID from the device's mac address.
-- @return The UUID string.
function M.uuid()
	local mac = get_mac_address()
	if not mac then
		log("Unable to get hardware mac address for UUID")
	end
	return uuid(mac)
end


local make_http_request
make_http_request = function(url, method, callback, headers, post_data, options, retry_intervals, retry_count, cancellation_token)
	if cancellation_token and cancellation_token.cancelled then
		callback(nil)
		return
	end
	http.request(url, method, function(self, id, result)
		if cancellation_token and cancellation_token.cancelled then
			callback(nil)
			return
		end
		log(result.response)
		local ok, decoded = pcall(json.decode, result.response)
		-- return result if everything is ok
		if ok and result.status >= 200 and result.status <= 299 then
			result.response = decoded
			callback(result.response)
			return
		end

		-- return the error if there are no more retries
		if retry_count > #retry_intervals then
			if not ok then
				result.response = { error = true, message = "Unable to decode response" }
			else
				result.response = { error = decoded.error or true, message = decoded.message, code = decoded.code }
			end
			callback(result.response)
			return
		end

		-- retry!
		local retry_interval = retry_intervals[retry_count]
		timer.delay(retry_interval, false, function()
			make_http_request(url, method, callback, headers, post_data, options, retry_intervals, retry_count + 1, cancellation_token)
		end)
	end, headers, post_data, options)

end



--- Make a HTTP request.
-- @param config The http config table, see Defold docs.
-- @param url_path The request URL.
-- @param query_params Query params string.
-- @param method The HTTP method string.
-- @param post_data String of post data.
-- @param callback The callback function.
-- @return The mac address string.
function M.http(config, url_path, query_params, method, post_data, retry_policy, cancellation_token, callback)
	local query_string = ""
	if next(query_params) then
		for query_key,query_value in pairs(query_params) do
			if type(query_value) == "table" then
				for _,v in ipairs(query_value) do
					query_string = ("%s%s%s=%s"):format(query_string, (#query_string == 0 and "?" or "&"), query_key, uri_encode_component(tostring(v)))
				end
			else
				query_string = ("%s%s%s=%s"):format(query_string, (#query_string == 0 and "?" or "&"), query_key, uri_encode_component(tostring(query_value)))
			end
		end
	end
	local url = ("%s%s%s"):format(config.http_uri, url_path, query_string)

	local headers = {}
	headers["Accept"] = "application/json"
	headers["Content-Type"] = "application/json"
	if config.bearer_token then
		headers["Authorization"] = ("Bearer %s"):format(config.bearer_token)
	elseif config.username then
		local credentials = b64_encode(config.username .. ":" .. config.password)
		headers["Authorization"] = ("Basic %s"):format(credentials)
	end

	local options = {
		timeout = config.timeout
	}

	log("HTTP", method, url)
	log("DATA", post_data)
	make_http_request(url, method, callback, headers, post_data, options, retry_policy or config.retry_policy, 1, cancellation_token)
end

--- Create a new socket with message handler.
-- @param config The socket config table, see Defold docs.
-- @param on_message Your function to process socket messages.
-- @return A socket table.
function M.socket_create(config, on_message)
	assert(config, "You must provide a config")
	assert(on_message, "You must provide a message handler")

	local socket = {}
	socket.config = config
	socket.scheme = config.use_ssl and "wss" or "ws"

	socket.cid = 0
	socket.requests = {}
	socket.on_message = on_message

	return socket
end

-- internal on_message, calls user defined socket.on_message function
local function on_message(socket, message)
	message = json.decode(message)
	if not message.cid then
		socket.on_message(socket, message)
		return
	end

	local callback = socket.requests[message.cid]
	if not callback then
		log("Unable to find callback for cid", message.cid)
		return
	end
	socket.requests[message.cid] = nil
	callback(message)
end

--- Connect a created socket using web sockets.
-- @param socket The socket table, see socket_create.
-- @param callback The callback function.
function M.socket_connect(socket, callback)
	assert(socket)
	assert(callback)

	local url = ("%s://%s:%d/ws?token=%s"):format(socket.scheme, socket.config.host, socket.config.port, uri.encode_component(socket.config.bearer_token))
	--const url = `${scheme}${this.host}:${this.port}/ws?lang=en&status=${encodeURIComponent(createStatus.toString())}&token=${encodeURIComponent(session.token)}`;

	log(url)

	local params = {
		protocol = nil,
		headers = nil,
		timeout = (socket.config.timeout or 0) * 1000,
	}
	socket.connection = websocket.connect(url, params, function(self, conn, data)
		if data.event == websocket.EVENT_CONNECTED then
			log("EVENT_CONNECTED")
			callback(true)
		elseif data.event == websocket.EVENT_DISCONNECTED then
			log("EVENT_DISCONNECTED: ", data.message)
			if socket.on_disconnect then socket.on_disconnect() end
		elseif data.event == websocket.EVENT_ERROR then
			log("EVENT_ERROR: ", data.message or data.error)
			callback(false, data.message or data.error)
		elseif data.event == websocket.EVENT_MESSAGE then
			log("EVENT_MESSAGE: ", data.message)
			on_message(socket, data.message)
		end
	end)
end

--- Send a socket message.
-- @param socket The socket table, see socket_create.
-- @param message The message string to send.
-- @param callback The callback function.
function M.socket_send(socket, message, callback)
	assert(socket and socket.connection, "You must provide a socket")
	assert(message, "You must provide a message to send")
	socket.cid = socket.cid + 1
	message.cid = tostring(socket.cid)
	socket.requests[message.cid] = callback

	local data = json.encode(message)
	-- Fix encoding of match_create and status_update messages to send {} instead of []
	if message.match_create ~= nil or message.status_update ~= nil then
		data = string.gsub(data, "%[%]", "{}")
	end

	local options = {
		type = websocket.DATA_TYPE_TEXT
	}
	websocket.send(socket.connection, data, options)
end

return M
