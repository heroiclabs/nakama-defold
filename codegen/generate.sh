#!/usr/bin/env bash

NAKAMA=../../nakama
NAKAMA_APIGRPC=${NAKAMA}/apigrpc
NAKAMA_COMMON=../../nakama-common/

go run rest.go ${NAKAMA_APIGRPC}/apigrpc.swagger.json > ../nakama/nakama.lua
python realtime.py ${NAKAMA_COMMON}  ../nakama/socket.lua

pushd ${NAKAMA}
NAKAMA_GRPC_VERISON=$(git describe --tags --abbrev=0)
popd

pushd ${NAKAMA_COMMON}
NAKAMA_COMMON_VERISON=$(git describe --tags --abbrev=0)
popd


echo "Nakama gRPC version: ${NAKAMA_GRPC_VERISON}"
echo "Nakama real-time version: ${NAKAMA_COMMON_VERISON}"
