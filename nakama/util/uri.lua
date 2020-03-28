-- uri component encode/decode (https://github.com/daurnimator/lua-http/blob/master/http/util.lua)

local M = {}

-- Encodes a character as a percent encoded string
local function char_to_pchar(c)
	return string.format("%%%02X", c:byte(1,1))
end

-- replaces all characters except the following with the appropriate UTF-8 escape sequences:
-- ; , / ? : @ & = + $
-- alphabetic, decimal digits, - _ . ! ~ * ' ( )
-- #
function M.encode(str)
	return (str:gsub("[^%;%,%/%?%:%@%&%=%+%$%w%-%_%.%!%~%*%'%(%)%#]", char_to_pchar))
end

-- escapes all characters except the following: alphabetic, decimal digits, - _ . ! ~ * ' ( )
function M.encode_component(str)
	return (str:gsub("[^%w%-_%.%!%~%*%'%(%)]", char_to_pchar))
end

-- unescapes url encoded characters
-- excluding characters that are special in urls
local decodeURI_blacklist = {}
for char in ("#$&+,/:;=?@"):gmatch(".") do
	decodeURI_blacklist[string.byte(char)] = true
end
local function decodeURI_helper(str)
	local x = tonumber(str, 16)
	if not decodeURI_blacklist[x] then
		return string.char(x)
	end
	-- return nothing; gsub will not perform the replacement
end
function M.decode(str)
	return (str:gsub("%%(%x%x)", decodeURI_helper))
end

-- Converts a hex string to a character
local function pchar_to_char(str)
	return string.char(tonumber(str, 16))
end

function M.decode_component(str)
	return (str:gsub("%%(%x%x)", pchar_to_char))
end

return M
