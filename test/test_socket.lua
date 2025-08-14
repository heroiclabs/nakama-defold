local nakama = require "nakama.nakama"
local test_engine = require "nakama.engine.test"
local b64 = require "nakama.util.b64"


context("Nakama socket", function()

	before(function()
		test_engine.reset()
	end)
	after(function() end)

	local function config()
		return {
			host = "127.0.0.1",
			port = 7350,
			use_ssl = false,
			username = "defaultkey",
			password = "",
			engine = test_engine,
			timeout = 10, -- connection timeout in seconds
		}
	end

	local function pprint(t)
		for k,v in pairs(t) do
			print(k, v)
		end
	end

	test("It should be able to create a socket", function()
		local client = nakama.create_client(config())
		local socket = client.create_socket()
		assert_not_nil(socket)
	end)

	test("It should be able to connect from a coroutine", function()
		local client = nakama.create_client(config())
		local socket = client.create_socket()

		local done = false
		coroutine.wrap(function()
			local result = socket.connect()
			assert_true(result)
			done = true
		end)()
		assert_true(done)
	end)

	test("It should be able to connect from a callback", function()
		local client = nakama.create_client(config())
		local socket = client.create_socket()

		local done = false
		socket.connect(function(result)
			assert_true(result)
			done = true
		end)
		assert_true(done)
	end)

	test("It should be able to disconnect", function()
		local client = nakama.create_client(config())
		local socket = client.create_socket()

		socket.disconnect()
		assert_true(true)
	end)

	test("It should encode sent match data", function()
		local client = nakama.create_client(config())
		local socket = client.create_socket()

		local done = false
		coroutine.wrap(function()
			socket.connect()
			local match_id = "id1234"
			local op_code = 1
			local data = "somedata"
			socket.match_data_send(match_id, op_code, data)

			local message = test_engine.get_socket_message()
			assert_not_nil(message)
			assert_not_nil(message.match_data_send)
			assert_equal(message.match_data_send.op_code, op_code)
			assert_equal(message.match_data_send.match_id, match_id)
			assert_equal(message.match_data_send.data, b64.encode(data))
			done = true
		end)()
		assert_true(done)
	end)

	test("It should decode received match data", function()
		local client = nakama.create_client(config())
		local socket = client.create_socket()

		local done = false
		coroutine.wrap(function()
			local data = "somedata"
			local message = {
				match_data = {
					data = b64.encode(data)
				}
			}

			socket.connect()
			socket.on_match_data(function(message)
				assert_not_nil(message)
				assert_not_nil(message.match_data)
				assert_not_nil(message.match_data.data)
				assert_equal(message.match_data.data, data, "Expected decoded match data")
				done = true
			end)

			test_engine.receive_socket_message(socket, message)
			
		end)()
		assert_true(done)
	end)

	test("It should send socket events to listeners", function()
		local client = nakama.create_client(config())
		local socket = client.create_socket()

		local events = { "notifications", "party_data", "stream_data" }
		local count = 0
		coroutine.wrap(function()
			socket.connect()

			for _,event_id in ipairs(events) do
				-- create event listener
				socket["on_" .. event_id](function(message)
					assert_not_nil(message)
					count = count + 1
				end)
				-- send message
				test_engine.receive_socket_message(socket, { [event_id] = {} })
			end
		end)()
		assert_equal(count, #events, "Expected all events to be received")
	end)
end)


