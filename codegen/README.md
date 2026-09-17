Generates Lua code from the Nakama and Satori API definitions (swagger and protobuf).

## Usage

Install [Go](https://go.dev/dl/) for your operating system and CPU architecture,
and Python 3. Verify the installation with `go version` and `python3 --version`.

Generate Lua bindings for the Nakama and Satori REST APIs and the Nakama realtime API:

```shell
./generate.sh
```
You can also run `./codegen/generate.sh` from the repository root. To select
specific tool installations, set `GO` and/or `PYTHON` to their executable paths:

```shell
GO=/path/to/go PYTHON=/path/to/python3 ./generate.sh
```

Generation stops on errors and only replaces the Lua files after all three
generators succeed.
