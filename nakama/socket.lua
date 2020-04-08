local client_async = require "websocket.client_async"
local uri = require "nakama.util.uri"
local async = require "nakama.util.async"
local json = require "nakama.util.json"

local M = {}

function M.create(config, use_ssl)
	assert(config, "You must provide a config")

	local socket = {}
	socket.config = config
	socket.scheme = use_sll and "wss" or "ws"

	socket.cid = 0
	socket.requests = {}

	socket.ws = client_async({
		connect_timeout = 5, -- optional timeout (in seconds) when connecting
	})

	socket.timer_handle = timer.delay(0.1, true, function(self, handle, time_elapsed)
		socket.ws:step()
	end)

	socket.ws:on_disconnected(function()
		print("Disconnected")
		if socket.on_disconnect then
			socket.on_disconnect()
		end
	end)

	socket.ws:on_message(function(message)
		print("Received message", message)
		message = json.decode(message)
		if not message.cid then
			print("Message has no cid")
			-- handle special message
			return
		end

		local callback = socket.requests[message.cid]
		if not callback then
			print("Unable to find callback for cid", message.cid)
			return
		end
		socket.requests[message.cid] = nil
		callback(message)
	end)

	return socket
end

function M.connect_async(socket, callback)
	assert(socket and socket.ws, "You must provide a socket")

	local url = ("%s://%s:%d/ws?token=%s"):format(socket.scheme, socket.config.host, socket.config.port, uri.encode_component(socket.config.bearer_token))
	--const url = `${scheme}${this.host}:${this.port}/ws?lang=en&status=${encodeURIComponent(createStatus.toString())}&token=${encodeURIComponent(session.token)}`;

	print(url)

	socket.ws:on_connected(function(ok, err)
		if callback then callback(ok, err) end
	end)
	
	socket.ws:connect(url)
end
function M.connect(socket)
	assert(socket and socket.ws, "You must provide a socket")
	return async(function(done)
		M.connect_async(socket, function(ok, err)
			done(ok, err)
		end)
	end)
end

function M.send_async(socket, message, callback)
	assert(socket and socket.ws, "You must provide a socket")
	assert(message, "You must provide a message to send")
	message.cid = socket.cid
	socket.cid = socket.cid + 1

	socket.requests[message.cid] = callback
	print("send", json.encode(message))
	socket.ws:send(json.encode(message))
end
function M.send(socket, message)
	print("send")
	pprint(socket, message)
	return async(function(done)
		M.send_async(socket, message, done)
	end)
end

function M.on_channelmessage(socket, fn)
	assert(socket and socket.ws, "You must provide a socket")
	socket.on_channelmessage = fn
end
function M.on_notification(socket, fn)
	assert(socket and socket.ws, "You must provide a socket")
	socket.on_notification = fn
end
function M.on_matchdata(socket, fn)
	assert(socket and socket.ws, "You must provide a socket")
	socket.on_matchdata = fn
end
function M.on_matchpresence(socket, fn)
	assert(socket and socket.ws, "You must provide a socket")
	socket.on_matchpresence = fn
end
function M.on_matchmakermatched(socket, fn)
	assert(socket and socket.ws, "You must provide a socket")
	socket.on_matchmakermatched = fn
end
function M.on_statuspresence(socket, fn)
	assert(socket and socket.ws, "You must provide a socket")
	socket.on_statuspresence = fn
end
function M.on_streampresence(socket, fn)
	assert(socket and socket.ws, "You must provide a socket")
	socket.on_streampresence = fn
end
function M.on_streamdata(socket, fn)
	assert(socket and socket.ws, "You must provide a socket")
	socket.on_streamdata = fn
end
function M.on_channelmessage(socket, fn)
	assert(socket and socket.ws, "You must provide a socket")
	socket.on_channelmessage = fn
end
function M.on_channelpresence(socket, fn)
	assert(socket and socket.ws, "You must provide a socket")
	socket.on_channelpresence = fn
end
function M.on_disconnect(socket, fn)
	assert(socket and socket.ws, "You must provide a socket")
	socket.on_disconnect = fn
end

return M
