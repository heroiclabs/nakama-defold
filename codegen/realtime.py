#!/usr/bin/env python

import re
import sys
import os

SOCKET_LUA = """
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
	if message.match_data and message.match_data.data then
		message.match_data.data = b64.encode(message.match_data.data)
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
-- %s


--
-- events
--
-- %s
-- on_channel_message

--- on_channel_message
-- @param socket Nakama Client Socket.
-- @param fn The callback function.
function M.on_channel_message(socket, fn)
	assert(socket, "You must provide a socket")
	assert(fn, "You must provide a function")
	socket.events.channel_message = fn
end
%s

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
		return "boolean"
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
	function_name = message_id

	lua = "\n"
	lua = lua + "--- " + function_name + "\n"
	for function_arg in function_args:
		lua = lua + "-- @param %s\n" % (function_arg)
	lua = lua + "function M.%s(%s)\n" % (function_name, function_args_string)
	lua = lua + "	assert(socket)\n"
	for prop in props:
		lua = lua + "	assert(_G.type(%s) == '%s' or %s == nil)\n" % (prop["name"], prop["type"], prop["name"])
	lua = lua + "	local message = {\n"
	lua = lua + "		%s = {\n" % message_id
	for prop in props:
		lua = lua + "			%s = %s,\n" % (prop["name"], prop["name"])
	lua = lua + "		}\n"
	lua = lua + "	}\n"
	lua = lua + "	return socket_send(socket, message, callback)\n"
	lua = lua + "end\n"
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
	return { "name": function_name, "lua": lua }



def messages_to_lua(rtapi):
	CHANNEL_MESSAGES = [ "ChannelJoin", "ChannelLeave", "ChannelMessageSend", "ChannelMessageRemove", "ChannelMessageUpdate" ]
	MATCH_MESSAGES = [ "MatchDataSend", "MatchCreate", "MatchJoin", "MatchLeave" ]
	MATCHMAKER_MESSAGES = [ "MatchmakerAdd", "MatchmakerRemove" ]
	PARTY_MESSAGES = [ "PartyCreate", "PartyJoin", "PartyLeave", "PartyPromote", "PartyAccept", "PartyRemove", "PartyClose", "PartyJoinRequestList", "PartyMatchmakerAdd", "PartyMatchmakerRemove", "PartyDataSend" ]
	STATUS_MESSAGES = [ "StatusFollow", "StatusUnfollow", "StatusUpdate" ]
	ALL_MESSAGES = CHANNEL_MESSAGES + MATCH_MESSAGES + MATCHMAKER_MESSAGES + PARTY_MESSAGES + STATUS_MESSAGES

	ids = []
	lua = ""
	for message_id in ALL_MESSAGES:
		lua = lua + message_to_lua(message_id, rtapi)
		ids.append(message_id)

	return { "ids": ids, "lua": lua }



def events_to_lua(rtapi, api):
	CHANNEL_EVENTS = [ "ChannelPresenceEvent" ]
	MATCH_EVENTS = [ "MatchPresenceEvent", "MatchData", "Match" ]
	MATCHMAKER_EVENTS = [ "MatchmakerMatched" ]
	NOTFICATION_EVENTS = [ "Notifications" ]
	PARTY_EVENTS = [ "PartyPresenceEvent", "Party", "PartyData", "PartyJoinRequest" ]
	STATUS_EVENTS = [ "StatusPresenceEvent", "Status" ]
	STREAM_EVENTS = [ "StreamData" ]
	OTHER_EVENTS = [ "Error" ]
	ALL_EVENTS = CHANNEL_EVENTS + MATCH_EVENTS + MATCHMAKER_EVENTS + NOTFICATION_EVENTS + PARTY_EVENTS + STATUS_EVENTS + STREAM_EVENTS + OTHER_EVENTS

	ids = []
	lua = ""
	for event_id in ALL_EVENTS:
		data = event_to_lua(event_id, rtapi)
		ids.append(data["name"])
		lua = lua + data["lua"]

	# also add single ChannelMessage event from rest API (it is references from the realtime API)
	data = event_to_lua("ChannelMessage", api)
	ids.append(data["name"])
	lua = lua + data["lua"]

	return { "ids": ids, "lua": lua }



if len(sys.argv) == 0:
	print("You must provide both an input file")
	sys.exit(1)

proto_path = sys.argv[1]
out_path = None

if len(sys.argv) > 2:
	out_path = sys.argv[2]

rtapi = read_as_string(os.path.join(proto_path, "rtapi", "realtime.proto"))
api = read_as_string(os.path.join(proto_path, "api", "api.proto"))

messages = messages_to_lua(rtapi)
events = events_to_lua(rtapi, api)

generated_lua = SOCKET_LUA % (messages["lua"], "\n-- ".join(events["ids"]), events["lua"])

if out_path:
	with open(out_path, "wb") as f:
		f.write(generated_lua)
else:
	print(generated_lua)


