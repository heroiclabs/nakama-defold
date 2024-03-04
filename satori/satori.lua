-- Code generated by codegen/generate-satori.py. DO NOT EDIT.

--[[--
The Satori client SDK for Defold.

@module satori
]]

local log = require "nakama.util.log"

local M = {}

-- helpers for parameter type checking
local function check_array(v) return type(v) == "table" end
local function check_string(v) return type(v) == "string" end
local function check_integer(v) return type(v) == "number" end
local function check_object(v) return type(v) == "table" end
local function check_boolean(v) return type(v) == "boolean" end

--- Create a Satori client instance.
-- @param config A table of configuration options.
-- config.host
-- config.port
-- @return Satori Client instance.
function M.create_client(config)
	assert(config, "You must provide a configuration")
	assert(config.host, "You must provide a host")
	assert(config.port, "You must provide a port")
	log("create_client()")

	local client = {}
	local scheme = config.use_ssl and "https" or "http"
	client.config = {}
	client.config.host = config.host
	client.config.port = config.port
	client.config.http_uri = ("%s://%s:%d"):format(scheme, config.host, config.port)

	local ignored_fns = { create_client = true, log = true }
	for name,fn in pairs(M) do
		if not ignored_fns[name] and type(fn) == "function" then
			log("setting " .. name)
			client[name] = function(...) return fn(client, ...) end
		end
	end

	return client
end

--
-- Satori REST API
--




local api_session = require "nakama.session"
local json = require "nakama.util.json"
local async = require "nakama.util.async"
local uri = require "nakama.util.uri"
local uri_encode = uri.encode

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


--- healthcheck
-- A healthcheck which load balancers can use to check the service.
-- @param client
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.healthcheck(client, callback, retry_policy, cancellation_token)
	log("healthcheck()")
	assert(client, "You must provide a client")


	local url_path = "/healthcheck"

	local query_params = {}

	local post_data = nil

	return http(client, callback, url_path, query_params, "GET", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- readycheck
-- A readycheck which load balancers can use to check the service.
-- @param client
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.readycheck(client, callback, retry_policy, cancellation_token)
	log("readycheck()")
	assert(client, "You must provide a client")


	local url_path = "/readycheck"

	local query_params = {}

	local post_data = nil

	return http(client, callback, url_path, query_params, "GET", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- authenticate
-- Authenticate against the server.
-- @param client
-- @param id_string (string) Identity ID. Must be between eight and 128 characters (inclusive).
-- Must be an alphanumeric string with only underscores and hyphens allowed. (REQUIRED)
-- @param default_table (table) Optional default properties to update with this call.
-- If not set, properties are left as they are on the server. (REQUIRED)
-- @param custom_table (table) Optional custom properties to update with this call.
-- If not set, properties are left as they are on the server. (REQUIRED)
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.authenticate(client, id_string, default_table, custom_table, callback, retry_policy, cancellation_token)
	log("authenticate()")
	assert(client, "You must provide a client")
	assert(check_string(id_string), "You must provide parameter 'id' of type 'string'")
	assert(check_object(default_table), "You must provide parameter 'default' of type 'object'")
	assert(check_object(custom_table), "You must provide parameter 'custom' of type 'object'")

	-- unset the token so username+password credentials will be used
	client.config.bearer_token = nil

	local url_path = "/v1/authenticate"

	local query_params = {}

	local post_data = json.encode({
		["id"] = id_string,
		["default"] = default_table,
		["custom"] = custom_table,
	})

	return http(client, callback, url_path, query_params, "POST", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			if not result.error then
				result = api_session.create(result)
			end
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- authenticate_logout
-- Log out a session, invalidate a refresh token, or log out all sessions/refresh tokens for a user.
-- @param client
-- @param token_string (string) Session token to log out. (REQUIRED)
-- @param refreshToken_string (string) Refresh token to invalidate. (REQUIRED)
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.authenticate_logout(client, token_string, refreshToken_string, callback, retry_policy, cancellation_token)
	log("authenticate_logout()")
	assert(client, "You must provide a client")
	assert(check_string(token_string), "You must provide parameter 'token' of type 'string'")
	assert(check_string(refreshToken_string), "You must provide parameter 'refreshToken' of type 'string'")

	-- unset the token so username+password credentials will be used
	client.config.bearer_token = nil

	local url_path = "/v1/authenticate/logout"

	local query_params = {}

	local post_data = json.encode({
		["token"] = token_string,
		["refreshToken"] = refreshToken_string,
	})

	return http(client, callback, url_path, query_params, "POST", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			if not result.error then
				result = api_session.create(result)
			end
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- authenticate_refresh
-- Refresh a user&#x27;s session using a refresh token retrieved from a previous authentication request.
-- @param client
-- @param refreshToken_string (string) Refresh token. (REQUIRED)
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.authenticate_refresh(client, refreshToken_string, callback, retry_policy, cancellation_token)
	log("authenticate_refresh()")
	assert(client, "You must provide a client")
	assert(check_string(refreshToken_string), "You must provide parameter 'refreshToken' of type 'string'")

	-- unset the token so username+password credentials will be used
	client.config.bearer_token = nil

	local url_path = "/v1/authenticate/refresh"

	local query_params = {}

	local post_data = json.encode({
		["refreshToken"] = refreshToken_string,
	})

	return http(client, callback, url_path, query_params, "POST", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			if not result.error then
				result = api_session.create(result)
			end
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- event
-- Publish an event for this session.
-- @param client
-- @param events_table (table) Some number of events produced by a client. (REQUIRED)
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.event(client, events_table, callback, retry_policy, cancellation_token)
	log("event()")
	assert(client, "You must provide a client")
	assert(check_array(events_table), "You must provide parameter 'events' of type 'array'")


	local url_path = "/v1/event"

	local query_params = {}

	local post_data = json.encode({
		["events"] = events_table,
	})

	return http(client, callback, url_path, query_params, "POST", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- get_experiments
-- Get or list all available experiments for this identity.
-- @param client
-- @param names_table (table) Experiment names; if empty string all experiments are returned.
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.get_experiments(client, names_table, callback, retry_policy, cancellation_token)
	log("get_experiments()")
	assert(client, "You must provide a client")


	local url_path = "/v1/experiment"

	local query_params = {}
	query_params["names"] = names_table

	local post_data = nil

	return http(client, callback, url_path, query_params, "GET", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- get_flags
-- List all available flags for this identity.
-- @param client
-- @param names_table (table) Flag names; if empty string all flags are returned.
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.get_flags(client, names_table, callback, retry_policy, cancellation_token)
	log("get_flags()")
	assert(client, "You must provide a client")


	local url_path = "/v1/flag"

	local query_params = {}
	query_params["names"] = names_table

	local post_data = nil

	return http(client, callback, url_path, query_params, "GET", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- identify
-- Enrich/replace the current session with new identifier.
-- @param client
-- @param id_string (string) Identity ID to enrich the current session and return a new session. Old session will no longer be usable. (REQUIRED)
-- @param default_table (table) Optional default properties to update with this call.
-- If not set, properties are left as they are on the server. (REQUIRED)
-- @param custom_table (table) Optional custom properties to update with this call.
-- If not set, properties are left as they are on the server. (REQUIRED)
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.identify(client, id_string, default_table, custom_table, callback, retry_policy, cancellation_token)
	log("identify()")
	assert(client, "You must provide a client")
	assert(check_string(id_string), "You must provide parameter 'id' of type 'string'")
	assert(check_object(default_table), "You must provide parameter 'default' of type 'object'")
	assert(check_object(custom_table), "You must provide parameter 'custom' of type 'object'")


	local url_path = "/v1/identify"

	local query_params = {}

	local post_data = json.encode({
		["id"] = id_string,
		["default"] = default_table,
		["custom"] = custom_table,
	})

	return http(client, callback, url_path, query_params, "PUT", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- delete_identity
-- Delete the caller&#x27;s identity and associated data.
-- @param client
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.delete_identity(client, callback, retry_policy, cancellation_token)
	log("delete_identity()")
	assert(client, "You must provide a client")


	local url_path = "/v1/identity"

	local query_params = {}

	local post_data = nil

	return http(client, callback, url_path, query_params, "DELETE", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- get_live_events
-- List available live events.
-- @param client
-- @param names_table (table) Live event names; if empty string all live events are returned.
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.get_live_events(client, names_table, callback, retry_policy, cancellation_token)
	log("get_live_events()")
	assert(client, "You must provide a client")


	local url_path = "/v1/live-event"

	local query_params = {}
	query_params["names"] = names_table

	local post_data = nil

	return http(client, callback, url_path, query_params, "GET", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- get_message_list
-- Get the list of messages for the identity.
-- @param client
-- @param limit_table (table) Max number of messages to return. Between 1 and 100.
-- @param forward_boolean (boolean) True if listing should be older messages to newer, false if reverse.
-- @param cursor_string (string) A pagination cursor, if any.
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.get_message_list(client, limit_table, forward_boolean, cursor_string, callback, retry_policy, cancellation_token)
	log("get_message_list()")
	assert(client, "You must provide a client")


	local url_path = "/v1/message"

	local query_params = {}
	query_params["limit"] = limit_table
	query_params["forward"] = forward_boolean
	query_params["cursor"] = cursor_string

	local post_data = nil

	return http(client, callback, url_path, query_params, "GET", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- delete_message
-- Deletes a message for an identity.
-- @param client
-- @param id_string (string) The identifier of the message. (REQUIRED)
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.delete_message(client, id_string, callback, retry_policy, cancellation_token)
	log("delete_message()")
	assert(client, "You must provide a client")
	assert(check_string(id_string), "You must provide parameter 'id' of type 'string'")


	local url_path = "/v1/message/{id}"
	url_path = url_path:gsub("{" .. "id" .. "}", uri_encode(id_string))

	local query_params = {}

	local post_data = nil

	return http(client, callback, url_path, query_params, "DELETE", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- update_message
-- Updates a message for an identity.
-- @param client
-- @param id_string (string) The identifier of the messages. (REQUIRED)
-- @param readTime_string (string) The time the message was read at the client. (REQUIRED)
-- @param consumeTime_string (string) The time the message was consumed by the identity. (REQUIRED)
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.update_message(client, id_string, readTime_string, consumeTime_string, callback, retry_policy, cancellation_token)
	log("update_message()")
	assert(client, "You must provide a client")
	assert(check_string(id_string), "You must provide parameter 'id' of type 'string'")
	assert(check_string(readTime_string), "You must provide parameter 'readTime' of type 'string'")
	assert(check_string(consumeTime_string), "You must provide parameter 'consumeTime' of type 'string'")


	local url_path = "/v1/message/{id}"
	url_path = url_path:gsub("{" .. "id" .. "}", uri_encode(id_string))

	local query_params = {}

	local post_data = json.encode({
		["readTime"] = readTime_string,
		["consumeTime"] = consumeTime_string,
	})

	return http(client, callback, url_path, query_params, "PUT", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- list_properties
-- List properties associated with this identity.
-- @param client
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.list_properties(client, callback, retry_policy, cancellation_token)
	log("list_properties()")
	assert(client, "You must provide a client")


	local url_path = "/v1/properties"

	local query_params = {}

	local post_data = nil

	return http(client, callback, url_path, query_params, "GET", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end

--- update_properties
-- Update identity properties.
-- @param client
-- @param default_table (table) Event default properties. (REQUIRED)
-- @param custom_table (table) Event custom properties. (REQUIRED)
-- @param recompute_boolean (boolean) Informs the server to recompute the audience membership of the identity. (REQUIRED)
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (table) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.update_properties(client, default_table, custom_table, recompute_boolean, callback, retry_policy, cancellation_token)
	log("update_properties()")
	assert(client, "You must provide a client")
	assert(check_object(default_table), "You must provide parameter 'default' of type 'object'")
	assert(check_object(custom_table), "You must provide parameter 'custom' of type 'object'")
	assert(check_boolean(recompute_boolean), "You must provide parameter 'recompute' of type 'boolean'")


	local url_path = "/v1/properties"

	local query_params = {}

	local post_data = json.encode({
		["default"] = default_table,
		["custom"] = custom_table,
		["recompute"] = recompute_boolean,
	})

	return http(client, callback, url_path, query_params, "PUT", post_data, retry_policy, cancellation_token, function(result)
		-- A successful response.
		if result.code == 200 then
			return result
		end
		-- An unexpected error response.
		return result
	end)
end


return M