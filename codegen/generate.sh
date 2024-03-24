#!/usr/bin/env bash

go run generate-rest.go template-satori.go template-common.go satori.swagger.json > ../satori/satori.lua 
go run generate-rest.go template-nakama.go template-common.go apigrpc.swagger.json > ../nakama/nakama.lua
python generate-nakama-realtime.py realtime.proto api.proto ../nakama/socket.lua
