local nakama = require "nakama.nakama"
local test_engine = require "nakama.engine.test"


context("Nakama client", function()

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

	test("It should be able to create a client", function()
		local config = config()
		local client = nakama.create_client(config)
		assert_not_nil(client)
	end)

	test("It should be able to call REST API functions", function()
		local token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiI1MjJkMGI5MS00NmQzLTRjY2ItYmIwYS0wNTFjYjUyOGNhMDMiLCJ1c24iOiJicml0emwiLCJleHAiOjE2NjE1OTA5Nzl9.r3h4QraXsXl-XmGQueYecjeb6223vtd1s-Ak1K_FrGM"
		local refresh_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiI1MjJkMGI5MS00NmQzLTRjY2ItYmIwYS0wNTFjYjUyOGNhMDMiLCJ1c24iOiJicml0emwiLCJleHAiOjE2NjE1ODczNzl9.AWASctuZx9A8YliCLSj9jtOi4fuXUZaWtRdNz1mMEEw"
		local data = {
			token = token,
		}
		local url_path = "/v2/account/authenticate/email"
		test_engine.set_http_response(url_path, data)

		coroutine.wrap(function()
			local client = nakama.create_client(config())
			local email = "super@heroes.com"
			local password = "batsignal"
			local session = client.authenticate_email(email, password)
			assert_not_nil(session)
			assert_equal(session.token, data.token)

			local request = test_engine.get_http_request(1)
			assert_not_nil(request)
			assert_equal(request.url_path, url_path)
			assert_equal(request.method, "POST")
			assert_equal(request.post_data, '{"password":"batsignal","email":"super@heroes.com"}')
			assert_not_nil(request.query_params)
		end)()
	end)

	test("It should be able to use coroutines", function()
		test_engine.set_http_response("/v2/account", {})

		local done = false
		coroutine.wrap(function()
			local client = nakama.create_client(config())
			local result = client.get_account()
			assert_not_nil(result)
			done = true
		end)()
		assert_true(done)
	end)

	test("It should be able to use callbacks", function()
		test_engine.set_http_response("/v2/account", {})

		local done = false
		local client = nakama.create_client(config())
		client.get_account(function(result)
			assert_not_nil(result)
			done = true
		end)
		assert_true(done)
	end)
end)


