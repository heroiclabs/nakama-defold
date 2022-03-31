#!/usr/bin/env bash

go run rest.go ../../nakama/apigrpc/apigrpc.swagger.json > ../nakama/nakama.lua
python realtime.py ../../nakama-common/rtapi/realtime.proto  ../nakama/socket.lua
