
local M = {}

local b64 = require "nakama.util.b64"
local async = require "nakama.util.async"
local log = require "nakama.util.log"

local function on_socket_message(socket, message)
	if message.match_data then
		message.match_data.data = b64.decode(message.match_data.data)
	end
	for event_id,_ in pairs(message) do
		if socket.events[event_id] then
			socket.events[event_id](message)
			return
		end
	end
	log("Unhandled message")
end

local function socket_send(socket, message, callback)
	if message.match_data_send and message.match_data_send.data then
		message.match_data_send.data = b64.encode(message.match_data_send.data)
	end

	if callback then
		socket.engine.socket_send(socket, message, callback)
	else
		return async(function(done)
			socket.engine.socket_send(socket, message, done)
		end)
	end
end


function M.create(client)
	local socket = client.engine.socket_create(client.config, on_socket_message)
	assert(socket, "No socket created")
	assert(type(socket) == "table", "The created instance must be a table")
	socket.client = client
	socket.engine = client.engine

	-- event handlers are registered here
	socket.events = {}

	-- set up function mappings on the socket instance itself
	for name,fn in pairs(M) do
		if name ~= "create" and type(fn) == "function" then
			socket[name] = function(...) return fn(socket, ...) end
		end
	end
	return socket
end


--- Attempt to connect a Nakama socket to the server.
-- @param socket The client socket to connect (from call to create_socket).
-- @param callback Optional callback to invoke with the result.
-- @return If no callback is provided the function returns the result.
function M.connect(socket, callback)
	assert(socket, "You must provide a socket")
	if callback then
		socket.engine.socket_connect(socket, callback)
	else
		return async(function(done)
			socket.engine.socket_connect(socket, done)
		end)
	end
end


--- Send message on Nakama socket.
-- @param socket The client socket to use when sending the message.
-- @param message The message string.
-- @param callback Optional callback to invoke with the result.
-- @return If no callback is provided the function returns the result.
function M.send(socket, message, callback)
	assert(socket, "You must provide a socket")
	assert(message, "You must provide a message")
	return socket_send(socket, message, callback)
end


--- On disconnect hook.
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_disconnect(socket, fn)
	assert(socket, "You must provide a socket")
	socket.on_disconnect = fn
end


--
-- messages
--
-- 
--- channel_join
-- @param socket
-- @param target
-- @param type
-- @param persistence
-- @param hidden
-- @param callback
function M.channel_join(socket, target, type, persistence, hidden, callback)
	assert(socket)
	assert(target == nil or _G.type(target) == 'string')
	assert(type == nil or _G.type(type) == 'number')
	assert(persistence == nil or _G.type(persistence) == 'boolean')
	assert(hidden == nil or _G.type(hidden) == 'boolean')
	local message = {
		channel_join = {
			target = target,
			type = type,
			persistence = persistence,
			hidden = hidden,
		}
	}
	return socket_send(socket, message, callback)
end

--- channel_leave
-- @param socket
-- @param channel_id
-- @param callback
function M.channel_leave(socket, channel_id, callback)
	assert(socket)
	assert(channel_id == nil or _G.type(channel_id) == 'string')
	local message = {
		channel_leave = {
			channel_id = channel_id,
		}
	}
	return socket_send(socket, message, callback)
end

--- channel_message_send
-- @param socket
-- @param channel_id
-- @param content
-- @param callback
function M.channel_message_send(socket, channel_id, content, callback)
	assert(socket)
	assert(channel_id == nil or _G.type(channel_id) == 'string')
	assert(content == nil or _G.type(content) == 'string')
	local message = {
		channel_message_send = {
			channel_id = channel_id,
			content = content,
		}
	}
	return socket_send(socket, message, callback)
end

--- channel_message_remove
-- @param socket
-- @param channel_id
-- @param message_id
-- @param callback
function M.channel_message_remove(socket, channel_id, message_id, callback)
	assert(socket)
	assert(channel_id == nil or _G.type(channel_id) == 'string')
	assert(message_id == nil or _G.type(message_id) == 'string')
	local message = {
		channel_message_remove = {
			channel_id = channel_id,
			message_id = message_id,
		}
	}
	return socket_send(socket, message, callback)
end

--- channel_message_update
-- @param socket
-- @param channel_id
-- @param message_id
-- @param content
-- @param callback
function M.channel_message_update(socket, channel_id, message_id, content, callback)
	assert(socket)
	assert(channel_id == nil or _G.type(channel_id) == 'string')
	assert(message_id == nil or _G.type(message_id) == 'string')
	assert(content == nil or _G.type(content) == 'string')
	local message = {
		channel_message_update = {
			channel_id = channel_id,
			message_id = message_id,
			content = content,
		}
	}
	return socket_send(socket, message, callback)
end

--- match_data_send
-- @param socket
-- @param match_id
-- @param op_code
-- @param data
-- @param presences
-- @param reliable
-- @param callback
function M.match_data_send(socket, match_id, op_code, data, presences, reliable, callback)
	assert(socket)
	assert(match_id == nil or _G.type(match_id) == 'string')
	assert(op_code == nil or _G.type(op_code) == 'number')
	assert(data == nil or _G.type(data) == 'string')
	assert(presences == nil or _G.type(presences) == 'table')
	assert(reliable == nil or _G.type(reliable) == 'boolean')
	local message = {
		match_data_send = {
			match_id = match_id,
			op_code = op_code,
			data = data,
			presences = presences,
			reliable = reliable,
		}
	}
	return socket_send(socket, message, callback)
end

--- match_create
-- @param socket
-- @param name
-- @param callback
function M.match_create(socket, name, callback)
	assert(socket)
	assert(name == nil or _G.type(name) == 'string')
	local message = {
		match_create = {
			name = name,
		}
	}
	return socket_send(socket, message, callback)
end

--- match_join
-- @param socket
-- @param match_id
-- @param token
-- @param metadata
-- @param callback
function M.match_join(socket, match_id, token, metadata, callback)
	assert(socket)
	assert(match_id == nil or _G.type(match_id) == 'string')
	assert(token == nil or _G.type(token) == 'string')
	assert(metadata == nil or _G.type(metadata) == 'table')
	local message = {
		match_join = {
			match_id = match_id,
			token = token,
			metadata = metadata,
		}
	}
	return socket_send(socket, message, callback)
end

--- match_leave
-- @param socket
-- @param match_id
-- @param callback
function M.match_leave(socket, match_id, callback)
	assert(socket)
	assert(match_id == nil or _G.type(match_id) == 'string')
	local message = {
		match_leave = {
			match_id = match_id,
		}
	}
	return socket_send(socket, message, callback)
end

--- matchmaker_add
-- @param socket
-- @param min_count
-- @param max_count
-- @param query
-- @param string_properties
-- @param numeric_properties
-- @param count_multiple
-- @param callback
function M.matchmaker_add(socket, min_count, max_count, query, string_properties, numeric_properties, count_multiple, callback)
	assert(socket)
	assert(min_count == nil or _G.type(min_count) == 'number')
	assert(max_count == nil or _G.type(max_count) == 'number')
	assert(query == nil or _G.type(query) == 'string')
	assert(string_properties == nil or _G.type(string_properties) == 'table')
	assert(numeric_properties == nil or _G.type(numeric_properties) == 'table')
	assert(count_multiple == nil or _G.type(count_multiple) == 'number')
	local message = {
		matchmaker_add = {
			min_count = min_count,
			max_count = max_count,
			query = query,
			string_properties = string_properties,
			numeric_properties = numeric_properties,
			count_multiple = count_multiple,
		}
	}
	return socket_send(socket, message, callback)
end

--- matchmaker_remove
-- @param socket
-- @param ticket
-- @param callback
function M.matchmaker_remove(socket, ticket, callback)
	assert(socket)
	assert(ticket == nil or _G.type(ticket) == 'string')
	local message = {
		matchmaker_remove = {
			ticket = ticket,
		}
	}
	return socket_send(socket, message, callback)
end

--- party_create
-- @param socket
-- @param open
-- @param max_size
-- @param callback
function M.party_create(socket, open, max_size, callback)
	assert(socket)
	assert(open == nil or _G.type(open) == 'boolean')
	assert(max_size == nil or _G.type(max_size) == 'number')
	local message = {
		party_create = {
			open = open,
			max_size = max_size,
		}
	}
	return socket_send(socket, message, callback)
end

--- party_join
-- @param socket
-- @param party_id
-- @param callback
function M.party_join(socket, party_id, callback)
	assert(socket)
	assert(party_id == nil or _G.type(party_id) == 'string')
	local message = {
		party_join = {
			party_id = party_id,
		}
	}
	return socket_send(socket, message, callback)
end

--- party_leave
-- @param socket
-- @param party_id
-- @param callback
function M.party_leave(socket, party_id, callback)
	assert(socket)
	assert(party_id == nil or _G.type(party_id) == 'string')
	local message = {
		party_leave = {
			party_id = party_id,
		}
	}
	return socket_send(socket, message, callback)
end

--- party_promote
-- @param socket
-- @param party_id
-- @param presence
-- @param callback
function M.party_promote(socket, party_id, presence, callback)
	assert(socket)
	assert(party_id == nil or _G.type(party_id) == 'string')
	assert(presence == nil or _G.type(presence) == 'table')
	local message = {
		party_promote = {
			party_id = party_id,
			presence = presence,
		}
	}
	return socket_send(socket, message, callback)
end

--- party_accept
-- @param socket
-- @param party_id
-- @param presence
-- @param callback
function M.party_accept(socket, party_id, presence, callback)
	assert(socket)
	assert(party_id == nil or _G.type(party_id) == 'string')
	assert(presence == nil or _G.type(presence) == 'table')
	local message = {
		party_accept = {
			party_id = party_id,
			presence = presence,
		}
	}
	return socket_send(socket, message, callback)
end

--- party_remove
-- @param socket
-- @param party_id
-- @param presence
-- @param callback
function M.party_remove(socket, party_id, presence, callback)
	assert(socket)
	assert(party_id == nil or _G.type(party_id) == 'string')
	assert(presence == nil or _G.type(presence) == 'table')
	local message = {
		party_remove = {
			party_id = party_id,
			presence = presence,
		}
	}
	return socket_send(socket, message, callback)
end

--- party_close
-- @param socket
-- @param party_id
-- @param callback
function M.party_close(socket, party_id, callback)
	assert(socket)
	assert(party_id == nil or _G.type(party_id) == 'string')
	local message = {
		party_close = {
			party_id = party_id,
		}
	}
	return socket_send(socket, message, callback)
end

--- party_join_request_list
-- @param socket
-- @param party_id
-- @param callback
function M.party_join_request_list(socket, party_id, callback)
	assert(socket)
	assert(party_id == nil or _G.type(party_id) == 'string')
	local message = {
		party_join_request_list = {
			party_id = party_id,
		}
	}
	return socket_send(socket, message, callback)
end

--- party_matchmaker_add
-- @param socket
-- @param party_id
-- @param min_count
-- @param max_count
-- @param query
-- @param string_properties
-- @param numeric_properties
-- @param count_multiple
-- @param callback
function M.party_matchmaker_add(socket, party_id, min_count, max_count, query, string_properties, numeric_properties, count_multiple, callback)
	assert(socket)
	assert(party_id == nil or _G.type(party_id) == 'string')
	assert(min_count == nil or _G.type(min_count) == 'number')
	assert(max_count == nil or _G.type(max_count) == 'number')
	assert(query == nil or _G.type(query) == 'string')
	assert(string_properties == nil or _G.type(string_properties) == 'table')
	assert(numeric_properties == nil or _G.type(numeric_properties) == 'table')
	assert(count_multiple == nil or _G.type(count_multiple) == 'number')
	local message = {
		party_matchmaker_add = {
			party_id = party_id,
			min_count = min_count,
			max_count = max_count,
			query = query,
			string_properties = string_properties,
			numeric_properties = numeric_properties,
			count_multiple = count_multiple,
		}
	}
	return socket_send(socket, message, callback)
end

--- party_matchmaker_remove
-- @param socket
-- @param party_id
-- @param ticket
-- @param callback
function M.party_matchmaker_remove(socket, party_id, ticket, callback)
	assert(socket)
	assert(party_id == nil or _G.type(party_id) == 'string')
	assert(ticket == nil or _G.type(ticket) == 'string')
	local message = {
		party_matchmaker_remove = {
			party_id = party_id,
			ticket = ticket,
		}
	}
	return socket_send(socket, message, callback)
end

--- party_data_send
-- @param socket
-- @param party_id
-- @param op_code
-- @param data
-- @param callback
function M.party_data_send(socket, party_id, op_code, data, callback)
	assert(socket)
	assert(party_id == nil or _G.type(party_id) == 'string')
	assert(op_code == nil or _G.type(op_code) == 'number')
	assert(data == nil or _G.type(data) == 'string')
	local message = {
		party_data_send = {
			party_id = party_id,
			op_code = op_code,
			data = data,
		}
	}
	return socket_send(socket, message, callback)
end

--- status_follow
-- @param socket
-- @param user_ids
-- @param usernames
-- @param callback
function M.status_follow(socket, user_ids, usernames, callback)
	assert(socket)
	assert(user_ids == nil or _G.type(user_ids) == 'string')
	assert(usernames == nil or _G.type(usernames) == 'string')
	local message = {
		status_follow = {
			user_ids = user_ids,
			usernames = usernames,
		}
	}
	return socket_send(socket, message, callback)
end

--- status_unfollow
-- @param socket
-- @param user_ids
-- @param callback
function M.status_unfollow(socket, user_ids, callback)
	assert(socket)
	assert(user_ids == nil or _G.type(user_ids) == 'string')
	local message = {
		status_unfollow = {
			user_ids = user_ids,
		}
	}
	return socket_send(socket, message, callback)
end

--- status_update
-- @param socket
-- @param status
-- @param callback
function M.status_update(socket, status, callback)
	assert(socket)
	assert(status == nil or _G.type(status) == 'string')
	local message = {
		status_update = {
			status = status,
		}
	}
	return socket_send(socket, message, callback)
end



--
-- events
--
-- on_channel_presence_event
-- on_match_presence_event
-- on_match_data
-- on_match
-- on_matchmaker_matched
-- on_notifications
-- on_party_presence_event
-- on_party
-- on_party_data
-- on_party_join_request
-- on_party_leader
-- on_status_presence_event
-- on_status
-- on_stream_data
-- on_error
-- on_channel_message

--- on_channel_presence_event
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_channel_presence_event(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.channel_presence_event = fn
end

--- on_match_presence_event
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_match_presence_event(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.match_presence_event = fn
end

--- on_match_data
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_match_data(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.match_data = fn
end

--- on_match
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_match(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.match = fn
end

--- on_matchmaker_matched
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_matchmaker_matched(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.matchmaker_matched = fn
end

--- on_notifications
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_notifications(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.notifications = fn
end

--- on_party_presence_event
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_party_presence_event(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.party_presence_event = fn
end

--- on_party
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_party(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.party = fn
end

--- on_party_data
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_party_data(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.party_data = fn
end

--- on_party_join_request
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_party_join_request(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.party_join_request = fn
end

--- on_party_leader
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_party_leader(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.party_leader = fn
end

--- on_status_presence_event
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_status_presence_event(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.status_presence_event = fn
end

--- on_status
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_status(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.status = fn
end

--- on_stream_data
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_stream_data(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.stream_data = fn
end

--- on_error
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_error(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.error = fn
end

--- on_channel_message
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_channel_message(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.channel_message = fn
end


-- Default case. Assumed as ROOM type.
M.CHANNELTYPE_UNSPECIFIED = 0
-- A room which anyone can join to chat.
M.CHANNELTYPE_ROOM = 1
-- A private channel for 1-on-1 chat.
M.CHANNELTYPE_DIRECT_MESSAGE = 2
-- A channel for group chat.
M.CHANNELTYPE_GROUP = 3


-- An unexpected result from the server.
M.ERROR_RUNTIME_EXCEPTION = 0
-- The server received a message which is not recognised.
M.ERROR_UNRECOGNIZED_PAYLOAD = 1
-- A message was expected but contains no content.
M.ERROR_MISSING_PAYLOAD = 2
-- Fields in the message have an invalid format.
M.ERROR_BAD_INPUT = 3
-- The match id was not found.
M.ERROR_MATCH_NOT_FOUND = 4
-- The match join was rejected.
M.ERROR_MATCH_JOIN_REJECTED = 5
-- The runtime function does not exist on the server.
M.ERROR_RUNTIME_FUNCTION_NOT_FOUND = 6
-- The runtime function executed with an error.
M.ERROR_RUNTIME_FUNCTION_EXCEPTION = 7

return M
