#!/usr/bin/env bash

go run rest.go ../../nakama/apigrpc/apigrpc.swagger.json > ../nakama/nakama.lua
python realtime.py ../../nakama-common/  ../nakama/socket.lua
