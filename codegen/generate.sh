#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

GO="${GO:-go}"
PYTHON="${PYTHON:-python3}"

if ! "$GO" version; then
	echo "Unable to run Go ($GO). Install Go for your CPU architecture ($(uname -m)), or set GO to a working Go executable." >&2
	exit 1
fi
if ! "$PYTHON" --version; then
	echo "Unable to run Python 3 ($PYTHON). Install Python 3, or set PYTHON to its executable." >&2
	exit 1
fi

# Generate everything before replacing any existing bindings.
output_dir=$(mktemp -d)
trap 'rm -rf "$output_dir"' EXIT

"$GO" run generate-rest.go template-satori.go template-common.go satori.swagger.json > "$output_dir/satori.lua"
"$GO" run generate-rest.go template-nakama.go template-common.go apigrpc.swagger.json > "$output_dir/nakama.lua"
"$PYTHON" generate-nakama-realtime.py realtime.proto api.proto "$output_dir/socket.lua"

cp "$output_dir/satori.lua" ../satori/satori.lua
cp "$output_dir/nakama.lua" ../nakama/nakama.lua
cp "$output_dir/socket.lua" ../nakama/socket.lua
