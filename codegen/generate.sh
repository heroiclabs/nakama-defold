#!/usr/bin/env bash

python generate-rest.py
python generate-nakama-realtime.py realtime.proto api.proto ../nakama/socket.lua
