local satori = require "satori.satori"
local test_engine = require "nakama.engine.test"
local json = require "nakama.util.json"
local log = require "nakama.util.log"
log.print()

context("Satori client", function()

	before(function()
		test_engine.reset()
	end)
	after(function() end)

	local function config()
		return {
			host = "127.0.0.1",
			api_key = "00000000-1111-2222-3333-444444444444",
			port = 7350,
			use_ssl = false,
			engine = test_engine,
			timeout = 10, -- connection timeout in seconds
		}
	end

	local function pprint(...)
		for i=1,select("#", ...) do
			local arg = select(i, ...)
			if type(arg) == "table" then
				for k,v in pairs(arg) do
					print(k, v)
				end
			else
				print(arg)
			end
		end
	end

	test("It should be able to create a client", function()
		local config = config()
		local client = satori.create_client(config)
		assert_not_nil(client)
	end)

	test("It should be able to authenticate", function()
		local token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiI1MjJkMGI5MS00NmQzLTRjY2ItYmIwYS0wNTFjYjUyOGNhMDMiLCJ1c24iOiJicml0emwiLCJleHAiOjE2NjE1OTA5Nzl9.r3h4QraXsXl-XmGQueYecjeb6223vtd1s-Ak1K_FrGM"
		local data = { token = token }
		local url_path = "/v1/authenticate"
		test_engine.set_http_response(url_path, data)

		coroutine.wrap(function()
			local client = satori.create_client(config())
			local id = "foobar"
			client.authenticate(nil, nil, id)

			local request = test_engine.get_http_request(1)
			assert_not_nil(request)
			assert_equal(request.url_path, url_path)
			assert_equal(request.method, "POST")

			local pd = json.decode(request.post_data)
			assert_equal(pd.id, id)
			assert_not_nil(request.query_params)
		end)()
	end)

	test("It should create a session on successful authentication", function()
		local token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzaWQiOiI5NzM3Zjc2My1kZDNkLTQ4OWMtYTI0Yy1hOTUwY2E1OWI5M2QiLCJpaWQiOiI3NDkzNDc3MS0zOTQ3LTQ2YjQtYzY5Zi0wYTc2ODAxMGYxOTciLCJleHAiOjE3MTc3NDg1NzMsImlhdCI6MTcxNzc0NDk3MywiYXBpIjoiZGVmb2xkIn0.v0Mnf-b1g738PWPSf-EsHqH1I6BpZ9QErmHU6t-SPpQ"
		local refresh_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzaWQiOiI5NzM3Zjc2My1kZDNkLTQ4OWMtYTI0Yy1hOTUwY2E1OWI5M2QiLCJpaWQiOiI3NDkzNDc3MS0zOTQ3LTQ2YjQtYzY5Zi0wYTc2ODAxMGYxOTciLCJleHAiOjE3MTc3NDg1NzMsImlhdCI6MTcxNzc0NDk3M30.IK9xAbIxSv68awVw8yiaYnTun_Dd-VJWjS3rld10NMI"
		local data = {
			token = token,
		}
		local url_path = "/v1/authenticate"
		test_engine.set_http_response(url_path, data)

		coroutine.wrap(function()
			local client = satori.create_client(config())
			local id = "foobar"
			local session = client.authenticate(nil, nil, id)
			assert_not_nil(session)
			assert_not_nil(session.created)
			assert_not_nil(session.expires)
			assert_equal(session.token, data.token)
		end)()
	end)

	test("It should be able to use coroutines", function()
		test_engine.set_http_response("/v1/experiment", {})

		local done = false
		print("before coroutine")
		coroutine.wrap(function()
			print("in coroutine create client")
			local client = satori.create_client(config())
			print("in coroutine get account")
			local result = client.get_experiments()
			print("in coroutine result", result)
			assert_not_nil(result)
			print("in coroutine done")
			done = true
		end)()
		print("after coroutine")
		assert_true(done)
	end)

	test("It should be able to use callbacks", function()
		test_engine.set_http_response("/v1/experiment", {})

		local done = false
		local client = satori.create_client(config())
		client.get_experiments(nil, function(result)
			assert_not_nil(result)
			done = true
		end)
		assert_true(done)
	end)
end)
