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

    * https://github.com/britzl/defold-websocket/archive/1.6.0.zip
    * https://github.com/britzl/defold-luasocket/archive/0.11.1.zip
    * https://github.com/britzl/defold-luasec/archive/1.1.0.zip

4. Use the connection credentials to initialise the nakama client.

    ```lua
    local defold = require "nakama.engine.defold"
    local nakama = require "nakama.nakama"
    local config = {
        host = "127.0.0.1",
        port = 7350,
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

The client can create one or more sockets with the server. Each socket can have it's own event listeners registered for responses received from the server.

Here's an example of creating a socket to join a chat room (similarly, `match_join` or `matchmaker_add` messages can be used to work with matchmaking system instead):

```lua
local client = nakama.create_client(config)

-- create socket
local socket = nakama.create_socket(client)

nakama.sync(function()
    -- connect
    local ok, err = nakama.socket_connect(socket)

    -- add socket listeners
    nakama.on_disconnect(socket, function(message)
        print("Disconnected!")
    end)
    nakama.on_channelpresence(socket, function(message)
        pprint(message)
    end)

    -- send channel join message
    local channel_id = "pineapple-pizza-lovers-room"
    local channel_join_message = {
        channel_join = {
            type = 1, -- 1 = room, 2 = Direct Message, 3 = Group
            target = channel_id,
            persistence = false,
            hidden = false,
        }
    }
    local result = nakama.socket_send(socket, channel_join_message)
end)
```

See [example](example/) directory with basic authentication and event listener flow.

Listeners available:

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

### Sending match data

Nakama [supports any binary content](https://heroiclabs.com/docs/gameplay-multiplayer-realtime/#send-data-messages) in `data` attribute of a match message. Regardless of your data type, the server **only accepts base64-encoded data**, so make sure you don't post plain-text data or even JSON, or Nakama server will claim the data malformed and disconnect your client (set server logging to `debug` to detect these events).

Here's an example of a proper match data message:

```lua
local b64 = require "nakama.util.b64"
local json = require "nakama.util.json"

local data = json.encode({
    dest_x = 1.0,
    dest_y = 0.1,
})

local net_msg = {
    match_data_send = {
        match_id = match_id,     -- you get it from on_matchmakermatched() listener in case
                                 -- of authoritative match, or after joining the relayed match;
        op_code = 1,             -- pick the op_code for yourself depending on the gameplay event;
        data = b64.encode(data), -- consider writing a convenience function for encoding your data
                                 -- in JSON and base64;
    }
}

nakama.sync(function()
    nakama.socket_send(socket, net_msg)
end)
```

In a relayed multiplayer, you'll be receiving other clients' messages as JSON with base64-encoded `data` key and have to decode them. Messages initiated _by the server_ in an authoritative match will come as valid JSON messages by default.

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
