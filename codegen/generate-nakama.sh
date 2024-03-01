#!/usr/bin/env bash

go run generate-nakama-rest.go apigrpc.swagger.json > ../nakama/nakama.lua
python generate-nakama-realtime.py realtime.proto api.proto ../nakama/socket.lua
