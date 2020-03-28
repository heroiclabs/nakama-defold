# Nakama Defold/Lua client

> JavaScript client for Nakama server written in TypeScript. For browser and React Native projects.

[Nakama](https://github.com/heroiclabs/nakama) is an open-source server designed to power modern games and apps. Features include user accounts, chat, social, matchmaker, realtime multiplayer, and much [more](https://heroiclabs.com).

This client implements the full API and socket options with the server. It's written in Lua 5.1 to be compatible with Lua based game engines.

(Full documentation is online - https://heroiclabs.com/docs/lua-client-guide)

## Getting Started

You'll need to setup the server and database before you can connect with the client. The simplest way is to use Docker but have a look at the [server documentation](https://github.com/heroiclabs/nakama#getting-started) for other options.

1. Install and run the servers. Follow these [instructions](https://heroiclabs.com/docs/install-docker-quickstart).

2. Add the client to your project.

  * In Defold projects you need to add the URL of a [stable release](https://github.com/defold/nakama-defold/releases) or the [latest development version](https://github.com/defold/nakama-defold/archive/master.zip) as a library dependency to `game.project`. The client will now show up in `nakama` folder in your project.


3. Use the connection credentials to initialise the nakama client.

    ```lua
    local nakama = require "nakama.nakama"
    local config = {
        base_uri = "http://127.0.0.1:7350",
        username = "defaultkey",
        password = "",
    }
    nakama.init(config)
    ```

## Usage

The client has many methods to execute various features in the server or open realtime socket connections with the server.

### Authenticate

There's a variety of ways to [authenticate](https://heroiclabs.com/docs/authentication) with the server. Authentication can create a user if they don't already exist with those credentials. It's also easy to authenticate with a social profile from Google Play Games, Facebook, Game Center, etc.

```lua
local email = "super@heroes.com"
local password = "batsignal"
local body = nakama.create_api_account_email(email, password)
local session = nakama.authenticate_email(body)
pprint(session)
```

### Sessions

When authenticated the server responds with an auth token (JWT) which can be used to authenticate API requests. The token contains useful properties and gets deserialized into a `session` table.

```lua
print(session.token) -- raw JWT token
print(session.user_id)
print(session.username)
print(session.expires)
print(session.created)

-- Use the token to authenticate future API requests
nakama.set_bearer_token(session.token)
```

It is recommended to store the auth token from the session and check at startup if it has expired. If the token has expired you must reauthenticate. The expiry time of the token can be changed as a setting in the server.

```lua
-- Assume we've stored the auth token
local api_session = require "nakama.api.session"
local token = sys.load(token_path)
local session = api_session.create(token)
if api_session.expired(session) then
    print("Session has expired. Must reauthenticate.")
else
    nakama.set_bearer_token(session.token)
end
```

### Requests

The client includes lots of builtin APIs for various features of the game server. These can be accessed with the methods which either use a callback function to return a result or yield until a result is received (the latter must be run from within a Lua coroutine). It can also call custom logic as RPC functions on the server. These can also be executed with a socket object.

```lua
local account = nakama.get_account()
print(account.user.id);
print(account.user.username);
print(account.wallet);
```

### Socket

The client can create one or more sockets with the server. Each socket can have it's own event listeners registered for responses received from the server.

__DOCUMENTATION TO BE ADDED__

## Contribute

The development roadmap is managed as GitHub issues and pull requests are welcome. If you're interested to enhance the code please open an issue to discuss the changes or drop in and discuss it in the [community forum](https://forum.heroiclabs.com).

### License

This project is licensed under the [Apache-2 License](https://github.com/heroiclabs/nakama-defold/blob/master/LICENSE).
