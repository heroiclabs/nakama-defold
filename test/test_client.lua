local nakama = require "nakama.nakama"
local test_engine = require "nakama.engine.test"
local json = require "nakama.util.json"
local log = require "nakama.util.log"
log.print()

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

	test("It should be able to authenticate", function()
		local token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiI1MjJkMGI5MS00NmQzLTRjY2ItYmIwYS0wNTFjYjUyOGNhMDMiLCJ1c24iOiJicml0emwiLCJleHAiOjE2NjE1OTA5Nzl9.r3h4QraXsXl-XmGQueYecjeb6223vtd1s-Ak1K_FrGM"
		local data = { token = token }
		local url_path = "/v2/account/authenticate/email"
		test_engine.set_http_response(url_path, data)

		coroutine.wrap(function()
			local client = nakama.create_client(config())
			local email = "super@heroes.com"
			local password = "batsignal"
			client.authenticate_email(email, password)

			local request = test_engine.get_http_request(1)
			assert_not_nil(request)
			assert_equal(request.url_path, url_path)
			assert_equal(request.method, "POST")

			local pd = json.decode(request.post_data)
			assert_equal(pd.password, password)
			assert_equal(pd.email, email)
			assert_not_nil(request.query_params)
		end)()
	end)

	test("It should create a session on successful authentication", function()
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
			assert_not_nil(session.created)
			assert_not_nil(session.expires)
			assert_equal(session.token, data.token)
			assert_equal(session.user_id, "522d0b91-46d3-4ccb-bb0a-051cb528ca03")
			assert_equal(session.username, "britzl")
		end)()
	end)

	test("It should be able to use coroutines", function()
		test_engine.set_http_response("/v2/account", {})

		local done = false
		print("before coroutine")
		coroutine.wrap(function()
			print("in coroutine create client")
			local client = nakama.create_client(config())
			print("in coroutine get account")
			local result = client.get_account()
			print("in coroutine result", result)
			assert_not_nil(result)
			print("in coroutine done")
			done = true
		end)()
		print("after coroutine")
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


