local client_async = require "websocket.client_async"

local M = {}

local ws = nil

function M.create()
	ws = client_async({
		connect_timeout = 5, -- optional timeout (in seconds) when connecting
	})

	ws:on_connected(function(ok, err)
		if ok then
			print("Connected")
			msg.post("#", "acquire_input_focus")
		else
			print("Unable to connect", err)
		end
	end)

	ws:on_disconnected(function()
		print("Disconnected")
	end)

	ws:on_message(function(message)
		print("Received message", message)
	end)
end

return M
