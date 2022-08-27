local session = require "nakama.session"

context("Session", function()
	before(function() end)
	after(function() end)

	test("It should be able to detect when a session has expired", function()
		local now = os.time()
		local expired_session = {
			expires = now - 1
		}
		local non_expired_session = {
			expires = now + 1
		}
		assert_true(session.expired(expired_session))
		assert_false(session.expired(non_expired_session))
	end)

	test("It should be able to create a session", function()
		local token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiI1MjJkMGI5MS00NmQzLTRjY2ItYmIwYS0wNTFjYjUyOGNhMDMiLCJ1c24iOiJicml0emwiLCJleHAiOjE2NjE1OTA5Nzl9.r3h4QraXsXl-XmGQueYecjeb6223vtd1s-Ak1K_FrGM"
		local refresh_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiI1MjJkMGI5MS00NmQzLTRjY2ItYmIwYS0wNTFjYjUyOGNhMDMiLCJ1c24iOiJicml0emwiLCJleHAiOjE2NjE1ODczNzl9.AWASctuZx9A8YliCLSj9jtOi4fuXUZaWtRdNz1mMEEw"
		local data = {
			token = token,
			refresh_token = refresh_token
		}

		local s = session.create(data)
		assert(s.created)
		assert_equal(s.token, token)
		assert_equal(s.expires, 1661590979)
		assert_equal(s.username, "britzl")
		assert_equal(s.user_id, "522d0b91-46d3-4ccb-bb0a-051cb528ca03")
	end)
end)