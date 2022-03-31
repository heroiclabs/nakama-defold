#!/usr/bin/env python

import re
import sys


SOCKET_LUA = """
local M = {}


local socket_event_functions = {}
local socket_message_functions = {}

local function on_socket_message(socket, message)
	for event_id,_ in pairs(message) do
		if socket.events[event_id] then
			socket.events[event_id](message)
			return
		end
	end
	log("Unhandled message")
end

--[[
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
]]--


function M.create(client)
	local socket = client.engine.socket_create(client.config, on_socket_message)
	assert(socket, "No socket created")
	assert(type(socket) == "table", "The created instance must be a table")
	socket.client = client
	socket.engine = client.engine

	socket.events = {}

	socket.send = M.send
	socket.connect = M.connect
	for name, fn in pairs(socket_message_functions) do
		socket[name] = function(...) return fn(socket, ...) end
	end
	for name, fn in pairs(socket_event_functions) do
		socket[name] = function(...) return fn(socket, ...) end
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
%s


--
-- events
--
%s

--- On disconnect hook.
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_disconnect(socket, fn)
	assert(socket, "You must provide a socket")
	socket.on_disconnect = fn
end

return M
"""

CAMEL_TO_SNAKE = re.compile(r'(?<!^)(?=[A-Z])')

def camel_to_snake(s):
	return CAMEL_TO_SNAKE.sub('_', s).lower()


def read_as_string(filename):
	with open(filename) as f:
		return f.read()


def get_proto_message(message_id, api):
	s = "message " + message_id + " \{(.*?)^\}"
	match = re.search(s, api, re.DOTALL | re.MULTILINE)
	if match:
		return match.group(1)
	else:
		return None


def type_to_lua(t):
	if t == "int32" or t == "int64" or t == "google.protobuf.Int32Value":
		return "number"
	elif t == "string" or t == "bytes" or t == "google.protobuf.StringValue":
		return "string"
	elif t == "google.protobuf.BoolValue" or t == "bool":
		return "bool"
	elif t == "map":
		return "table"
	else:
		print("WARNING: Unknown type '%s' - Will use type 'table'" % t)
		return "table"


def parse_proto_message(message):
	# simplify map
	message = re.sub("map<.*?>", "map", message)
	# remove inner enum
	message = re.sub("enum .* \{.*?}?", "", message, 0, re.DOTALL | re.MULTILINE)
	# remove inner message
	message = re.sub("message .* \{.*?}?", "", message, 0, re.DOTALL | re.MULTILINE)

	properties = []
	s = "\s*(repeated )?(\S*) (.*) = .*;"
	match = re.findall(s, message)
	for m in match:
		if m[1]:
			lua_type = type_to_lua(m[1])
			name = m[2]
			repeated = m[0] == "repeated "
			if repeated:
				lua_type == "table"
			properties.append({ "type": lua_type, "name": name, "repeated": repeated})
	return properties


def message_to_lua(message_id, api):
	message = get_proto_message(message_id, api)
	if not message:
		print("Unable to find message %s" % message_id)
		return

	props = parse_proto_message(message)
	function_args = [ "socket" ]
	for prop in props:
		function_args.append(prop["name"])
	function_args.append("callback")

	function_args_string = ", ".join(function_args)

	message_id = camel_to_snake(message_id)
	function_name = "send_" + message_id

	lua = "\n"
	lua = lua + "--- " + function_name + "\n"
	for function_arg in function_args:
		lua = lua + "-- @param %s\n" % (function_arg)
	lua = lua + "function M.%s(%s)\n" % (function_name, function_args_string)
	lua = lua + "	assert(socket)\n"
	for prop in props:
		lua = lua + "	assert(_G.type(%s) == '%s')\n" % (prop["name"], prop["type"])
	lua = lua + "	local message = {\n"
	lua = lua + "		%s = {\n" % message_id
	for prop in props:
		lua = lua + "			%s = %s,\n" % (prop["name"], prop["name"])
	lua = lua + "		}\n"
	lua = lua + "	}\n"
	lua = lua + "	return socket.send(socket, message, callback)\n"
	lua = lua + "end\n"
	lua = lua + "socket_message_functions.%s = M.%s\n" % (function_name, function_name)
	return lua


def event_to_lua(event_id, api):
	event = get_proto_message(event_id, api)
	if not event:
		print("Unable to find event %s" % event_id)
		return
	
	event_id = camel_to_snake(event_id)
	function_name = "on_" + event_id

	lua = "\n"
	lua = lua + "--- " + function_name + "\n"
	lua = lua + "-- @param socket Nakama Client Socket.\n"
	lua = lua + "-- @param fn The callback function.\n"
	lua = lua + "function M.%s(socket, fn)\n" % (function_name)
	lua = lua + "	assert(socket, \"You must provide a socket\")\n"
	lua = lua + "	assert(fn, \"You must provide a function\")\n"
	lua = lua + "	socket.events.%s = fn\n" % (event_id)
	lua = lua + "end\n"
	lua = lua + "socket_event_functions.%s = M.%s\n" % (function_name, function_name)
	return lua


if len(sys.argv) < 2:
	print("You must provide both an input and output file")
	sys.exit(1)

proto_path = sys.argv[1]
out_path = sys.argv[2]



api = read_as_string(proto_path)


CHANNEL_MESSAGES = [ "ChannelJoin", "ChannelLeave", "ChannelMessageSend", "ChannelMessageRemove" ]
MATCH_MESSAGES = [ "MatchData", "MatchDataSend", "MatchJoin", "MatchLeave" ]
MATCHMAKER_MESSAGES = [ "MatchmakerAdd", "MatchmakerRemove" ]
PARTY_MESSAGES = [ "PartyCreate", "PartyJoin", "PartyLeave", "PartyPromote", "PartyAccept", "PartyRemove", "PartyClose", "PartyJoinRequestList", "PartyMatchmakerAdd", "PartyMatchmakerRemove", "PartyDataSend" ]
STATUS_MESSAGES = [ "StatusFollow", "StatusUnfollow", "StatusUpdate" ]
ALL_MESSAGES = CHANNEL_MESSAGES + MATCH_MESSAGES + MATCHMAKER_MESSAGES + PARTY_MESSAGES + STATUS_MESSAGES


CHANNEL_EVENTS = [ "ChannelPresenceEvent" ]
MATCH_EVENTS = [ "MatchPresenceEvent" ]
MATCHMAKER_EVENTS = [ "MatchmakerMatched" ]
NOTFICATION_EVENTS = [ "Notifications" ]
PARTY_EVENTS = [ "PartyPresenceEvent", "Party", "PartyData" ]
STATUS_EVENTS = [ "StatusPresenceEvent" ]
STREAM_EVENTS = [ "StreamData" ]
ALL_EVENTS = CHANNEL_EVENTS + MATCH_EVENTS + MATCHMAKER_EVENTS + NOTFICATION_EVENTS + PARTY_EVENTS + STREAM_EVENTS + STREAM_EVENTS

messages_lua = ""
for message_id in ALL_MESSAGES:
	messages_lua = messages_lua + message_to_lua(message_id, api)

events_lua = ""
for event_id in ALL_EVENTS:
	events_lua = events_lua + event_to_lua(event_id, api)


with open(out_path, "wb") as f:
	f.write(SOCKET_LUA % (messages_lua, events_lua))


