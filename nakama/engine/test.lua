local uuid = require "nakama.util.uuid"

local M = {}

-----------------
-- TEST HELPER --
-----------------

local http_request_response = {}
local http_request_queue = {}
local socket_send_queue = {}

function M.set_http_response(path, response)
	assert(path, response)
	http_request_response[path] = response
end

function M.get_http_request()
	return table.remove(http_request_queue)
end

function M.get_socket_message()
	return table.remove(socket_send_queue)
end

function M.receive_socket_message(socket, message)
	socket.on_message(socket, message)
end

function M.reset()
	http_request_response = {}
	http_request_queue = {}
	socket_send_queue = {}
end

----------------
-- ENGINE API --
----------------

function M.uuid()
	return uuid("")
end

function M.http(config, url_path, query_params, method, post_data, retry_policy, cancellation_token, callback)
	local request = {
		config = config,
		url_path = url_path,
		query_params = query_params,
		method = method,
		post_data = post_data
	}
	table.insert(http_request_queue, request)

	local response = http_request_response[url_path]
	callback(response)
end

function M.socket_create(config, on_message)
	local socket = {
		on_message = on_message
	}
	return socket
end

function M.socket_connect(socket, callback)
	local result = true
	callback(result)
end

function M.socket_send(socket, message, callback)
	table.insert(socket_send_queue, message)
	local result = {}
	callback(result)
end


return M
