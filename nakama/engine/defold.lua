local log = require "nakama.util.log"

local b64 = require "nakama.util.b64"
local uri = require "nakama.util.uri"
local json = require "nakama.util.json"
local uuid = require "nakama.util.uuid"

local b64_encode = b64.encode
local b64_decode = b64.decode
local uri_encode_component = uri.encode_component
local uri_decode_component = uri.decode_component
local uri_encode = uri.encode
local uri_decode = uri.decode

uuid.seed()

local M = {}

local function get_mac_address()
	local ifaddrs = sys.get_ifaddrs()
	for _,interface in ipairs(ifaddrs) do
		if interface.mac then
			return interface.mac
		end
	end
	return nil
end

function M.uuid()
	local mac = get_mac_address()
	if not mac then
		log("Unable to get hardware mac address for UUID")
	end
	return uuid(mac)
end


function M.http(config, url_path, query_params, method, post_data, callback)
	local query_string = ""
	if next(query_params) then
		for query_key,query_value in pairs(query_params) do
			if type(query_value) == "table" then
				for _,v in ipairs(query_value) do
					query_string = ("%s%s%s=%s"):format(query_string, (#query_string == 0 and "?" or "&"), query_key, uri_encode_component(tostring(v)))
				end
			else
				query_string = ("%s%s%s=%s"):format(query_string, (#query_string == 0 and "?" or "&"), query_key, uri_encode_component(tostring(query_value)))
			end
		end
	end
	local url = ("%s%s%s"):format(config.http_uri, url_path, query_string)

	local headers = {}
	headers["Accept"] = "application/json"
	headers["Content-Type"] = "application/json"
	if config.bearer_token then
		headers["Authorization"] = ("Bearer %s"):format(config.bearer_token)
	elseif config.username then
		local credentials = b64_encode(config.username .. ":" .. config.password)
		headers["Authorization"] = ("Basic %s"):format(credentials)
	end

	local options = {
		timeout = config.timeout
	}

	log("HTTP", method, url)
	log("DATA", post_data)
	http.request(url, method, function(self, id, result)
		if result.response then
			log(result.response)
			result.response = json.decode(result.response)
		end
		callback(result.response)
	end, headers, post_data, options)
end

return M
