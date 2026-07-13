#!/bin/sh
set -e
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

# Validate required inputs
require_input "INPUT_APP" "$INPUT_APP"
set_rack

echo "Building $INPUT_APP on $CONVOX_RACK"

set -- --app "$INPUT_APP" --description "$INPUT_DESCRIPTION" --id
if [ "$INPUT_CACHED" = "false" ]; then set -- "$@" --no-cache; fi
if [ -n "$INPUT_MANIFEST" ]; then set -- "$@" -m "$INPUT_MANIFEST"; fi
if [ "$INPUT_EXTERNAL" = "true" ]; then set -- "$@" --external; fi

release=$(convox build "$@")

if [ -z "$release" ]; then
  echo "::error::Build failed — convox build returned no release ID"
  exit 1
fi

write_output "RELEASE" "$release"
persist_env "RELEASE" "$release"
