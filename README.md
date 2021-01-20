# Nakama Defold/Lua client

> Lua client for Nakama server written in Lua 5.1.

[Nakama](https://github.com/heroiclabs/nakama) is an open-source server designed to power modern games and apps. Features include user accounts, chat, social, matchmaker, realtime multiplayer, and much [more](https://heroiclabs.com).

This client implements the full API and socket options with the server. It's written in Lua 5.1 to be compatible with Lua based game engines.

Full documentation is [WIP online](https://heroiclabs.com/docs/lua-client-guide) - see [Cocos2d-x JS docs](https://heroiclabs.com/docs/cocos2d-x-js-client-guide/) for reference until the Lua docs are complete: most of the examples there are easily portable as Nakama concepts apply the same way.

## Getting Started

You'll need to setup the server and database before you can connect with the client. The simplest way is to use Docker but have a look at the [server documentation](https://github.com/heroiclabs/nakama#getting-started) for other options.

1. Install and run the servers. Follow these [instructions](https://heroiclabs.com/docs/install-docker-quickstart).

2. Add the client to your project.

  * In Defold projects you need to add the URL of a [stable release](https://github.com/heroiclabs/nakama-defold/releases) or the [latest development version](https://github.com/heroiclabs/nakama-defold/archive/master.zip) as a library dependency to `game.project`. The client will now show up in `nakama` folder in your project.

3. Add dependencies to your project. In Defold projects you need to add the following dependencies to game.project:

    * https://github.com/defold/extension-websocket/archive/1.5.2.zip

4. Use the connection credentials to initialise the nakama client.

    ```lua
    local defold = require "nakama.engine.defold"
    local nakama = require "nakama.nakama"
    local config = {
        host = "127.0.0.1",
        port = 7350,
        use_ssl = false,
        username = "defaultkey",
        password = "",
        engine = defold,
    }
    local client = nakama.create_client(config)
    ```

## Usage

The client has many methods to execute various features in the server or open realtime socket connections with the server.

### Authenticate

There's a variety of ways to [authenticate](https://heroiclabs.com/docs/authentication) with the server. Authentication can create a user if they don't already exist with those credentials. It's also easy to authenticate with a social profile from Google Play Games, Facebook, Game Center, etc.

```lua
local client = nakama.create_client(config)

local email = "super@heroes.com"
local password = "batsignal"
local body = nakama.create_api_account_email(email, password)
local session = nakama.authenticate_email(client, body)
pprint(session)
```

> _Note_: see [Requests](#Requests) section below for running this snippet (a)synchronously.

### Sessions

When authenticated the server responds with an auth token (JWT) which can be used to authenticate API requests. The token contains useful properties and gets deserialized into a `session` table.

```lua
local client = nakama.create_client(config)

print(session.token) -- raw JWT token
print(session.user_id)
print(session.username)
print(session.expires)
print(session.created)

-- Use the token to authenticate future API requests
nakama.set_bearer_token(client, session.token)
```

It is recommended to store the auth token from the session and check at startup if it has expired. If the token has expired you must reauthenticate. The expiry time of the token can be changed as a setting in the server.

```lua
local client = nakama.create_client(config)

-- Assume we've stored the auth token
local nakama_session = require "nakama.session"
local token = sys.load(token_path)
-- Note: creating session requires a session table, or at least a table with 'token' key
local session = nakama_session.create({ token = token })
if nakama_session.expired(session) then
    print("Session has expired. Must reauthenticate.")
else
    nakama.set_bearer_token(client, session.token)
end
```

### Requests

The client includes lots of built-in APIs for various features of the game server. These can be accessed with the methods which either use a callback function to return a result (ie. asynchronous) or yield until a result is received (ie. synchronous and must be run within a Lua coroutine).

```lua
local client = nakama.create_client(config)

-- using a callback
nakama.get_account(client, function(account)
    print(account.user.id);
    print(account.user.username);
    print(account.wallet);
end)

-- if run from within a coroutine
local account = nakama.get_account(client)
print(account.user.id);
print(account.user.username);
print(account.wallet);
```

The Nakama client provides a convenience function for creating and starting a coroutine to run multiple requests synchronously one after the other:

```lua
nakama.sync(function()
    local account = nakama.get_account(client)
    local result = nakama.update_account(client, request)
end)
```


### Socket

You can connect to the server over a realtime WebSocket connection to send and receive chat messages, get notifications, and matchmake into a multiplayer match.

You first need to create a realtime socket to the server:

```lua
local client = nakama.create_client(config)

-- create socket
local socket = nakama.create_socket(client)

nakama.sync(function()
    -- connect
    local ok, err = nakama.socket_connect(socket)
end)
```

Then proceed to join a chat channel and send a message:

```lua
-- send channel join message
local channel_id = "pineapple-pizza-lovers-room"
local channel_join_message = nakama.create_channel_join_message(1, channel_id, false, false)
local result = nakama.socket_send(socket, channel_join_message)

-- send channel messages
local channel_message_send = nakama.create_channel_message_send_message(channel_id, "Pineapple doesn't belong on a pizza!")
local result = nakama.socket_send(socket, channel_message_send)
```


#### Handle events

A client socket has event listeners which are called on various events received from the server. Example:

```lua
nakama.on_disconnect(socket, function(message)
    print("Disconnected!")
end)
```

Available listeners:

* `on_disconnect` - Handles an event for when the client is disconnected from the server.
* `on_error` - Receives events about server errors.
* `on_notification` - Receives live in-app notifications sent from the server.
* `on_channelmessage` - Receives realtime chat messages sent by other users.
* `on_channelpresence` - Handles join and leave events within chat.
* `on_matchdata` - Receives realtime multiplayer match data.
* `on_matchpresence` - Handles join and leave events within realtime multiplayer.
* `on_matchmakermatched` - Received when the matchmaker has found a suitable match.
* `on_statuspresence` - Handles status updates when subscribed to a user status feed.
* `on_streampresence` - Receives stream join and leave event.
* `on_streamdata` - Receives stream data sent by the server.


### Match data

Nakama [supports any binary content](https://heroiclabs.com/docs/gameplay-multiplayer-realtime/#send-data-messages) in `data` attribute of a match message. Regardless of your data type, the server **only accepts base64-encoded data**, so make sure you don't post plain-text data or even JSON, or Nakama server will claim the data malformed and disconnect your client (set server logging to `debug` to detect these events).

Nakama will automatically base64 encode your match data if the message was created using `nakama.create_match_data_message()`. Nakama will also automatically base64 decode any received match data before calling the `on_matchdata` listener.

```lua

local json = require "nakama.util.json"

local match_id = "..."
local op_code = 1
local data = json.encode({
    dest_x = 1.0,
    dest_y = 0.1,
})

-- create and send a match data message. The data will be automatically base64 encoded.
local message = nakama.create_match_data_message(match_id, op_code, data)
nakama.socket_send(socket, message)
```

In a relayed multiplayer, you'll be receiving other clients' messages. The client has already base64 decoded the message data before sending it to the `on_matchdata` listener. If the data was JSON encoded, like in the example above, you need to decode it yourself:

```lua
nakama.on_matchdata(socket, function(message)
    local match_data = message.match_data
    local data = json.decode(match_data.data)
    pprint(data)                            -- gameplay coordinates from the example above
end)
```

Messages initiated _by the server_ in an authoritative match will come as valid JSON by default.


## Adapting to other engines

Adapting the Nakama Defold client to another Lua based engine should be as easy as providing another engine module when configuring the Nakama client:

```lua
local myengine = require "nakama.engine.myengine"
local nakama = require "nakama.nakama"
local config = {
    engine = myengine,
}
local client = nakama.create_client(config)
```

The engine module must provide the following functions:

* `http(config, url_path, query_params, method, post_data, callback)` - Make HTTP request.
  * `config` - Config table passed to `nakama.create()`
  * `url_path` - Path to append to the base uri
  * `query_params` - Key-value pairs to use as URL query parameters
  * `method` - "GET", "POST"
  * `post_data` - Data to post
  * `callback` - Function to call with result (response)

* `socket_create(config, on_message)` - Create socket. Must return socket instance (table with engine specific socket state).
  * `config` - Config table passed to `nakama.create()`
  * `on_message` - Function to call when a message is sent from the server

* `socket_connect(socket, callback)` - Connect socket.
  * `socket` - Socket instance returned from `socket_create()`
  * `callback` - Function to call with result (ok, err)

* `socket_send(socket, message, callback)` - Send message on socket.
  * `socket` - Socket instance returned from `socket_create()`
  * `message` - Message to send
  * `callback` - Function to call with message returned as a response (message)


## Contribute

The development roadmap is managed as GitHub issues and pull requests are welcome. If you're interested to enhance the code please open an issue to discuss the changes or drop in and discuss it in the [community forum](https://forum.heroiclabs.com).

### License

This project is licensed under the [Apache-2 License](https://github.com/heroiclabs/nakama-defold/blob/master/LICENSE).
