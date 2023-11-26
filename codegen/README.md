Generates Lua code from the Nakama swagger definition in the main Nakama repository and the Nakama RealTime protobuf definition in the Nakama-Common repository.

## Usage

Generate the REST API:

```shell
go run rest.go /path/to/nakama/apigrpc/apigrpc.swagger.json > ../nakama/nakama.lua
```

Generate the RealTime API:

```shell
python realtime.py /path/to/nakama-common > ../nakama/socket.lua
```
