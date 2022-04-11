# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Fixed
- Runtime error when an unhandled socket message is received (#43)


## [3.0.0] - 2022-04-08
Please note that the Defold SDK version is not synchronised with the version of the Nakama server!

### Changed
- [BREAKING] Major overhaul of the generated code and how it interacts with the Nakama APIs.
- Socket creation and socket events have been moved to `nakama/socket.lua`. This includes sending events and adding socket event listeners.
- Removed message creation functions in favor of including all message arguments in the functions sending the messages.
- Added message functions to the client and socket instances. Compare `nakama.do_foo(client, ...)` and `client.do_foo(...)`. The old approach of passing the client or socket instance as the first argument still exists to help with backwards compatibility.


## [2.1.2] - 2021-09-29
### Fixed
- Status follow and unfollow messages used the wrong argument name.


## [2.1.1] - 2021-08-09
### Fixed
- Encoding of empty status update message.


## [2.1.0] - 2021-06-01
### Added
- Generated new version of the API. New API functions: nakama.validate_purchase_apple(), nakama.validate_purchase_google(), nakama.validate_purchase_huawei(), nakama.session_logout(), nakama.write_tournament_record2(), nakama.import_steam_friends()

### Changed
- Signatures for a few functions operating on user groups and friends.


## [2.0.0] - 2021-02-23
### Changed
- Updated to the new native WebSocket extension for Defold (https://github.com/defold/extension-websocket). To use Nakama with Defold you now only need to add a dependency to the WebSocket extension.

### Fixed
- HTTP requests handle HTTP status codes outside of the 200-299 range as errors. The general error handling based on the response from Nakama has also been improved.
- Match create messages are encoded correctly when the message is empty.
- [Issue 14](https://github.com/heroiclabs/nakama-defold/issues/14): Attempt to call global 'uri_encode' (a nil value)
- Upgrade code generator to new Swagger format introduces with Nakama v.2.14.0
- Do not use Lua default values for variables in `create_` methods to prevent data reset on backend


## [1.1.1] - 2020-06-30
### Fixed
- Fixes issues with re-authentication (by dropping an existing bearer token when calling an authentication function)


## [1.1.0] - 2020-06-21
### Added
- Support for encoding of match data (json+base64) using new utility module

### Fixed
- Use of either http or https connection via `config.use_ssl`


## [1.0.1] - 2020-05-31
### Fixed
- The default logging was not working


## [1.0.0] - 2020-05-25
### Added
- First public release
