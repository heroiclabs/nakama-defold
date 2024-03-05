local async = require "nakama.util.async"

-- cancellation tokens associated with a coroutine
local cancellation_tokens = {}

-- cancel a cancellation token
function M.cancel(token)
	assert(token)
	token.cancelled = true
end

-- create a cancellation token
-- use this to cancel an ongoing API call or a sequence of API calls
-- @return token Pass the token to a call to nakama.sync() or to any of the API calls
function M.cancellation_token()
	local token = {
		cancelled = false
	}
	function token.cancel()
		token.cancelled = true
	end
	return token
end

-- Private
-- Run code within a coroutine
-- @param fn The code to run
-- @param cancellation_token Optional cancellation token to cancel the running code
function M.sync(fn, cancellation_token)
	assert(fn)
	local co = nil
	co = coroutine.create(function()
		cancellation_tokens[co] = cancellation_token
		fn()
		cancellation_tokens[co] = nil
	end)
	local ok, err = coroutine.resume(co)
	if not ok then
		log(err)
		cancellation_tokens[co] = nil
	end
end

-- http request helper used to reduce code duplication in all API functions below
local function http(client, callback, url_path, query_params, method, post_data, retry_policy, cancellation_token, handler_fn)
	if callback then
		log(url_path, "with callback")
		client.engine.http(client.config, url_path, query_params, method, post_data, retry_policy, cancellation_token, function(result)
			if not cancellation_token or not cancellation_token.cancelled then
				callback(handler_fn(result))
			end
		end)
	else
		log(url_path, "with coroutine")
		local co = coroutine.running()
		assert(co, "You must be running this from withing a coroutine")

		-- get cancellation token associated with this coroutine
		cancellation_token = cancellation_tokens[co]
		if cancellation_token and cancellation_token.cancelled then
			cancellation_tokens[co] = nil
			return
		end

		return async(function(done)
			client.engine.http(client.config, url_path, query_params, method, post_data, retry_policy, cancellation_token, function(result)
				if cancellation_token and cancellation_token.cancelled then
					cancellation_tokens[co] = nil
					return
				end
				done(handler_fn(result))
			end)
		end)
	end
end
