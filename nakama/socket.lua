
local M = {}


local socket_events = {}

local function on_socket_message(socket, message)
	for event_id,event_fn in pairs(socket_events) do
		if message[event_id] and socket[event_id] then
			socket[event_id](message)
			return
		end
	end
	log("Unhandled message")
end

local function on_socket_message(socket, message)
	if message.notifications then
		if socket.on_notification then
			for n in ipairs(message.notifications.notifications) do
				socket.on_notification(message)
			end
		end
	elseif message.match_data then
		if socket.on_matchdata then
			message.match_data.data = b64.decode(message.match_data.data)
			socket.on_matchdata(message)
		end
	elseif message.match_presence_event then
		if socket.on_matchpresence then socket.on_matchpresence(message) end
	elseif message.matchmaker_matched then
		if socket.on_matchmakermatched then socket.on_matchmakermatched(message) end
	elseif message.status_presence_event then
		if socket.on_statuspresence then socket.on_statuspresence(message) end
	elseif message.stream_presence_event then
		if socket.on_streampresence then socket.on_streampresence(message) end
	elseif message.stream_data then
		if socket.on_streamdata then socket.on_streamdata(message) end
	elseif message.channel_message then
		if socket.on_channelmessage then socket.on_channelmessage(message) end
	elseif message.channel_presence_event then
		if socket.on_channelpresence then socket.on_channelpresence(message) end
	else
		log("Unhandled message")
	end
end



function M.create(client)
	local socket = client.engine.socket_create(client.config, on_socket_message)
	assert(socket, "No socket created")
	assert(type(socket) == "table", "The created instance must be a table")
	socket.client = client
	socket.engine = client.engine

	socket.send = M.send
	socket.connect = M.connect
	for name, fn in pairs(M) do
		if name:find("^send_") then
			socket[name] = fn
		end
	end
	for name, fn in pairs(M) do
		if name:find("^on_") then
			socket[name] = fn
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
	if callback then
		socket.engine.socket_send(socket, message, callback)
	else
		return async(function(done)
			socket.engine.socket_send(socket, message, done)
		end)
	end
end


--
-- messages
--

--- send_channel_join
-- @param socket
-- @param target
-- @param type
-- @param persistence
-- @param hidden
-- @param callback
function M.send_channel_join(socket, target, type, persistence, hidden, callback)
	assert(socket)
	assert(_G.type(target) == 'string')
	assert(_G.type(type) == 'number')
	assert(_G.type(persistence) == 'bool')
	assert(_G.type(hidden) == 'bool')
	local message = {
		channel_join = {
			target = target,
			type = type,
			persistence = persistence,
			hidden = hidden,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_channel_leave
-- @param socket
-- @param channel_id
-- @param callback
function M.send_channel_leave(socket, channel_id, callback)
	assert(socket)
	assert(_G.type(channel_id) == 'string')
	local message = {
		channel_leave = {
			channel_id = channel_id,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_channel_message_send
-- @param socket
-- @param channel_id
-- @param content
-- @param callback
function M.send_channel_message_send(socket, channel_id, content, callback)
	assert(socket)
	assert(_G.type(channel_id) == 'string')
	assert(_G.type(content) == 'string')
	local message = {
		channel_message_send = {
			channel_id = channel_id,
			content = content,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_channel_message_remove
-- @param socket
-- @param channel_id
-- @param message_id
-- @param callback
function M.send_channel_message_remove(socket, channel_id, message_id, callback)
	assert(socket)
	assert(_G.type(channel_id) == 'string')
	assert(_G.type(message_id) == 'string')
	local message = {
		channel_message_remove = {
			channel_id = channel_id,
			message_id = message_id,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_match_data
-- @param socket
-- @param match_id
-- @param presence
-- @param op_code
-- @param data
-- @param reliable
-- @param callback
function M.send_match_data(socket, match_id, presence, op_code, data, reliable, callback)
	assert(socket)
	assert(_G.type(match_id) == 'string')
	assert(_G.type(presence) == 'table')
	assert(_G.type(op_code) == 'number')
	assert(_G.type(data) == 'string')
	assert(_G.type(reliable) == 'bool')
	local message = {
		match_data = {
			match_id = match_id,
			presence = presence,
			op_code = op_code,
			data = data,
			reliable = reliable,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_match_data_send
-- @param socket
-- @param match_id
-- @param op_code
-- @param data
-- @param presences
-- @param reliable
-- @param callback
function M.send_match_data_send(socket, match_id, op_code, data, presences, reliable, callback)
	assert(socket)
	assert(_G.type(match_id) == 'string')
	assert(_G.type(op_code) == 'number')
	assert(_G.type(data) == 'string')
	assert(_G.type(presences) == 'table')
	assert(_G.type(reliable) == 'bool')
	local message = {
		match_data_send = {
			match_id = match_id,
			op_code = op_code,
			data = data,
			presences = presences,
			reliable = reliable,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_match_join
-- @param socket
-- @param metadata
-- @param callback
function M.send_match_join(socket, metadata, callback)
	assert(socket)
	assert(_G.type(metadata) == 'table')
	local message = {
		match_join = {
			metadata = metadata,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_match_leave
-- @param socket
-- @param match_id
-- @param callback
function M.send_match_leave(socket, match_id, callback)
	assert(socket)
	assert(_G.type(match_id) == 'string')
	local message = {
		match_leave = {
			match_id = match_id,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_matchmaker_add
-- @param socket
-- @param min_count
-- @param max_count
-- @param query
-- @param string_properties
-- @param numeric_properties
-- @param count_multiple
-- @param callback
function M.send_matchmaker_add(socket, min_count, max_count, query, string_properties, numeric_properties, count_multiple, callback)
	assert(socket)
	assert(_G.type(min_count) == 'number')
	assert(_G.type(max_count) == 'number')
	assert(_G.type(query) == 'string')
	assert(_G.type(string_properties) == 'table')
	assert(_G.type(numeric_properties) == 'table')
	assert(_G.type(count_multiple) == 'number')
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
	return socket.send(socket, message, callback)
end

--- send_matchmaker_remove
-- @param socket
-- @param ticket
-- @param callback
function M.send_matchmaker_remove(socket, ticket, callback)
	assert(socket)
	assert(_G.type(ticket) == 'string')
	local message = {
		matchmaker_remove = {
			ticket = ticket,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_party_create
-- @param socket
-- @param open
-- @param max_size
-- @param callback
function M.send_party_create(socket, open, max_size, callback)
	assert(socket)
	assert(_G.type(open) == 'bool')
	assert(_G.type(max_size) == 'number')
	local message = {
		party_create = {
			open = open,
			max_size = max_size,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_party_join
-- @param socket
-- @param party_id
-- @param callback
function M.send_party_join(socket, party_id, callback)
	assert(socket)
	assert(_G.type(party_id) == 'string')
	local message = {
		party_join = {
			party_id = party_id,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_party_leave
-- @param socket
-- @param party_id
-- @param callback
function M.send_party_leave(socket, party_id, callback)
	assert(socket)
	assert(_G.type(party_id) == 'string')
	local message = {
		party_leave = {
			party_id = party_id,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_party_promote
-- @param socket
-- @param party_id
-- @param presence
-- @param callback
function M.send_party_promote(socket, party_id, presence, callback)
	assert(socket)
	assert(_G.type(party_id) == 'string')
	assert(_G.type(presence) == 'table')
	local message = {
		party_promote = {
			party_id = party_id,
			presence = presence,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_party_accept
-- @param socket
-- @param party_id
-- @param presence
-- @param callback
function M.send_party_accept(socket, party_id, presence, callback)
	assert(socket)
	assert(_G.type(party_id) == 'string')
	assert(_G.type(presence) == 'table')
	local message = {
		party_accept = {
			party_id = party_id,
			presence = presence,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_party_remove
-- @param socket
-- @param party_id
-- @param presence
-- @param callback
function M.send_party_remove(socket, party_id, presence, callback)
	assert(socket)
	assert(_G.type(party_id) == 'string')
	assert(_G.type(presence) == 'table')
	local message = {
		party_remove = {
			party_id = party_id,
			presence = presence,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_party_close
-- @param socket
-- @param party_id
-- @param callback
function M.send_party_close(socket, party_id, callback)
	assert(socket)
	assert(_G.type(party_id) == 'string')
	local message = {
		party_close = {
			party_id = party_id,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_party_join_request_list
-- @param socket
-- @param party_id
-- @param callback
function M.send_party_join_request_list(socket, party_id, callback)
	assert(socket)
	assert(_G.type(party_id) == 'string')
	local message = {
		party_join_request_list = {
			party_id = party_id,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_party_matchmaker_add
-- @param socket
-- @param party_id
-- @param min_count
-- @param max_count
-- @param query
-- @param string_properties
-- @param numeric_properties
-- @param count_multiple
-- @param callback
function M.send_party_matchmaker_add(socket, party_id, min_count, max_count, query, string_properties, numeric_properties, count_multiple, callback)
	assert(socket)
	assert(_G.type(party_id) == 'string')
	assert(_G.type(min_count) == 'number')
	assert(_G.type(max_count) == 'number')
	assert(_G.type(query) == 'string')
	assert(_G.type(string_properties) == 'table')
	assert(_G.type(numeric_properties) == 'table')
	assert(_G.type(count_multiple) == 'number')
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
	return socket.send(socket, message, callback)
end

--- send_party_matchmaker_remove
-- @param socket
-- @param party_id
-- @param ticket
-- @param callback
function M.send_party_matchmaker_remove(socket, party_id, ticket, callback)
	assert(socket)
	assert(_G.type(party_id) == 'string')
	assert(_G.type(ticket) == 'string')
	local message = {
		party_matchmaker_remove = {
			party_id = party_id,
			ticket = ticket,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_party_data_send
-- @param socket
-- @param party_id
-- @param op_code
-- @param data
-- @param callback
function M.send_party_data_send(socket, party_id, op_code, data, callback)
	assert(socket)
	assert(_G.type(party_id) == 'string')
	assert(_G.type(op_code) == 'number')
	assert(_G.type(data) == 'string')
	local message = {
		party_data_send = {
			party_id = party_id,
			op_code = op_code,
			data = data,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_status_follow
-- @param socket
-- @param user_ids
-- @param usernames
-- @param callback
function M.send_status_follow(socket, user_ids, usernames, callback)
	assert(socket)
	assert(_G.type(user_ids) == 'string')
	assert(_G.type(usernames) == 'string')
	local message = {
		status_follow = {
			user_ids = user_ids,
			usernames = usernames,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_status_unfollow
-- @param socket
-- @param user_ids
-- @param callback
function M.send_status_unfollow(socket, user_ids, callback)
	assert(socket)
	assert(_G.type(user_ids) == 'string')
	local message = {
		status_unfollow = {
			user_ids = user_ids,
		}
	}
	return socket.send(socket, message, callback)
end

--- send_status_update
-- @param socket
-- @param status
-- @param callback
function M.send_status_update(socket, status, callback)
	assert(socket)
	assert(_G.type(status) == 'string')
	local message = {
		status_update = {
			status = status,
		}
	}
	return socket.send(socket, message, callback)
end



--
-- events
--

--- on_channel_presence_event
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_channel_presence_event(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.on_channel_presence_event = fn
end
socket_events.on_channel_presence_event = M.on_channel_presence_event

--- on_match_presence_event
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_match_presence_event(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.on_match_presence_event = fn
end
socket_events.on_match_presence_event = M.on_match_presence_event

--- on_matchmaker_matched
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_matchmaker_matched(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.on_matchmaker_matched = fn
end
socket_events.on_matchmaker_matched = M.on_matchmaker_matched

--- on_notifications
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_notifications(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.on_notifications = fn
end
socket_events.on_notifications = M.on_notifications

--- on_party_presence_event
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_party_presence_event(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.on_party_presence_event = fn
end
socket_events.on_party_presence_event = M.on_party_presence_event

--- on_party
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_party(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.on_party = fn
end
socket_events.on_party = M.on_party

--- on_party_data
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_party_data(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.on_party_data = fn
end
socket_events.on_party_data = M.on_party_data

--- on_stream_data
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_stream_data(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.on_stream_data = fn
end
socket_events.on_stream_data = M.on_stream_data

--- on_stream_data
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_stream_data(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.on_stream_data = fn
end
socket_events.on_stream_data = M.on_stream_data


--- On disconnect hook.
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_disconnect(socket, fn)
	assert(socket, "You must provide a socket")
	socket.on_disconnect = fn
end

return M
