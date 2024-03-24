package main

const COMMON_TEMPLATE string = `
local log = require "nakama.util.log"
local retries = require "nakama.util.retries"
local async = require "nakama.util.async"
local api_session = require "nakama.session"
local socket = require "nakama.socket"

local M = {}

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

--
-- Enums
--

{{- range $defname, $definition := .Definitions }}
{{- $classname := $defname | title }}
{{- if $definition.Enum }}

--- {{ $classname | pascalToSnake }}
-- {{ $definition.Description | stripNewlines }}
{{- range $i, $enum := $definition.Enum }}
M.{{ $classname | uppercase }}_{{ $enum }} = "{{ $enum }}"
{{- end }}
{{- end }}
{{- end }}


--
-- Objects
--

{{- range $defname, $definition := .Definitions }}
{{- $classname := $defname | title }}
{{- if $definition.Properties }}

--- create_{{ $classname | pascalToSnake }}
-- {{ $definition.Description | stripNewlines }}
{{- range $propname, $property := $definition.Properties }}
{{- $luaType := luaType $property.Type $property.Ref }}
{{- $varName := varName $propname $property.Type $property.Ref | pascalToSnake }}
-- @param {{ $varName }} ({{ $luaType }}) {{ $property.Description | stripNewlines}}
{{- end }}
function M.create_{{ $classname | pascalToSnake }}(
	{{- range $propname, $property := $definition.Properties }}
	{{- $luaType := luaType $property.Type $property.Ref }}
	{{- $varName := varName $propname $property.Type $property.Ref | pascalToSnake }}{{ $varName }}, {{- end }}_)
	{{- range $propname, $property := $definition.Properties }}
	{{- $luaType := luaType $property.Type $property.Ref }}
	{{- $varName := varName $propname $property.Type $property.Ref | pascalToSnake }}
	assert(not {{ $varName }} or type({{ $varName }}) == "{{ $luaType }}", "Argument '{{ $varName }}' must be 'nil' or of type '{{ $luaType }}'")
	{{- end }}
	return {
		{{- range $propname, $property := $definition.Properties }}
		{{- $luaType := luaType $property.Type $property.Ref }}
		{{- $varName := varName $propname $property.Type $property.Ref | pascalToSnake }}
		["{{ $propname | pascalToSnake }}"] = {{ $varName}},
		{{- end }}
	}
end
{{- end }}
{{- end }}


{{- range $url, $path := .Paths }}
	{{- range $method, $operation := $path}}

--- {{ $operation.OperationId | pascalToSnake | removePrefix }}
-- {{ $operation.Summary | stripNewlines }}
-- @param client Client.
{{- range $i, $parameter := $operation.Parameters }}
{{- $luaType := luaType $parameter.Type $parameter.Schema.Ref }}
{{- $varName := varName $parameter.Name $parameter.Type $parameter.Schema.Ref }}
{{- $varName := $varName | pascalToSnake }}
{{- $varComment := varComment $parameter.Name $parameter.Type $parameter.Schema.Ref $parameter.Items.Type }}
{{- if and (eq $parameter.In "body") $parameter.Schema.Ref }}
{{- bodyFunctionArgsDocs $parameter.Schema.Ref }}
{{- end }}
{{- if and (eq $parameter.In "body") $parameter.Schema.Type }}
-- @param {{ $parameter.Name }} ({{ $parameter.Schema.Type }}) {{ $parameter.Description | stripNewlines }}
{{- end }}
{{- if ne $parameter.In "body" }}
-- @param {{ $varName }} ({{ $parameter.Schema.Type }}) {{ $parameter.Description | stripNewlines }}
{{- end }}

{{- end }}
-- @param callback (function) Optional callback function
-- A coroutine is used and the result is returned if no callback function is provided.
-- @param retry_policy (function) Optional retry policy used specifically for this call or nil
-- @param cancellation_token (table) Optional cancellation token for this call
-- @return The result.
function M.{{ $operation.OperationId | pascalToSnake | removePrefix }}(client
	{{- range $i, $parameter := $operation.Parameters }}
	{{- $luaType := luaType $parameter.Type $parameter.Schema.Ref }}
	{{- $varName := varName $parameter.Name $parameter.Type $parameter.Schema.Ref }}
	{{- $varName := $varName | pascalToSnake }}
	{{- $varComment := varComment $parameter.Name $parameter.Type $parameter.Schema.Ref $parameter.Items.Type }}
	{{- if and (eq $parameter.In "body") $parameter.Schema.Ref }}
	{{- bodyFunctionArgs $parameter.Schema.Ref}}
	{{- end }}
	{{- if and (eq $parameter.In "body") $parameter.Schema.Type }}, {{ $parameter.Name }} {{- end }}
	{{- if ne $parameter.In "body" }}, {{ $varName }} {{- end }}
	{{- end }}, callback, retry_policy, cancellation_token)
	assert(client, "You must provide a client")
	{{- range $parameter := $operation.Parameters }}
	{{- $varName := varName $parameter.Name $parameter.Type $parameter.Schema.Ref }}
	{{- if eq $parameter.In "body" }}
	{{- bodyFunctionArgsAssert $parameter.Schema.Ref}}
	{{- end }}
	{{- if and (eq $parameter.In "body") $parameter.Schema.Type }}
	assert({{- if $parameter.Required }}{{ $parameter.Name }} and {{ end }}type({{ $parameter.Name }}) == "{{ $parameter.Schema.Type }}", "Argument '{{ $parameter.Name }}' must be of type '{{ $parameter.Schema.Type }}'")
	{{- end }}

	{{- end }}

	{{- if $operation.OperationId | isAuthenticateMethod }}
	-- unset the token so username+password credentials will be used
	client.config.bearer_token = nil

	{{- end}}

	local url_path = "{{- $url }}"
	{{- range $parameter := $operation.Parameters }}
	{{- $varName := varName $parameter.Name $parameter.Type $parameter.Schema.Ref }}
	{{- if eq $parameter.In "path" }}
	url_path = url_path:gsub("{{- print "{" $parameter.Name "}"}}", uri_encode({{ $varName | pascalToSnake }}))
	{{- end }}
	{{- end }}

	local query_params = {}
	{{- range $parameter := $operation.Parameters}}
	{{- $varName := varName $parameter.Name $parameter.Type $parameter.Schema.Ref }}
	{{- if eq $parameter.In "query"}}
	query_params["{{- $parameter.Name }}"] = {{ $varName | pascalToSnake }}
	{{- end}}
	{{- end}}

	local post_data = nil
	{{- range $parameter := $operation.Parameters }}
	{{- $varName := varName $parameter.Name $parameter.Type $parameter.Schema.Ref }}
	{{- if eq $parameter.In "body" }}
	{{- if $parameter.Schema.Ref }}
	post_data = json.encode({
		{{- bodyFunctionArgsTable $parameter.Schema.Ref}}	})
	{{- end }}
	{{- if $parameter.Schema.Type }}
	post_data = json.encode({{ $parameter.Name }})
	{{- end }}
		{{- end }}
	{{- end }}

	return http(client, callback, url_path, query_params, "{{- $method | uppercase }}", post_data, retry_policy, cancellation_token, function(result)
		{{- if $operation.Responses.Ok.Schema.Ref }}
		if not result.error and {{ $operation.Responses.Ok.Schema.Ref | cleanRef | pascalToSnake }} then
			result = {{ $operation.Responses.Ok.Schema.Ref | cleanRef | pascalToSnake }}.create(result)
		end
		{{- end }}
		return result
	end)
end
	{{- end }}
{{- end }}
`