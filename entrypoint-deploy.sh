#!/bin/sh
set -e
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

# Validate required inputs
require_input "INPUT_APP" "$INPUT_APP"
set_password
set_host
set_rack

echo "Deploying $INPUT_APP to $CONVOX_RACK"

set -- --app "$INPUT_APP" --description "$INPUT_DESCRIPTION"
if [ "$INPUT_CACHED" = "false" ]; then set -- "$@" --no-cache; fi
if [ -n "$INPUT_MANIFEST" ]; then set -- "$@" -m "$INPUT_MANIFEST"; fi
if [ "$INPUT_EXTERNAL" = "true" ]; then set -- "$@" --external; fi

convox deploy "$@" --wait
