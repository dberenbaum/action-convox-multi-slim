#!/bin/sh
set -e
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

# Validate required inputs
require_input "INPUT_APP" "$INPUT_APP"
require_input "INPUT_DESTINATIONAPP" "$INPUT_DESTINATIONAPP"
require_input "INPUT_DESTINATIONRACK" "$INPUT_DESTINATIONRACK"
set_rack

echo "Migrating $INPUT_APP from $CONVOX_RACK to $INPUT_DESTINATIONAPP on $INPUT_DESTINATIONRACK"

build=$(convox builds --app "$INPUT_APP" | awk '$2 == "complete" {print $1; exit}')

if [ -z "$build" ]; then
  echo "::error::No completed build found for $INPUT_APP"
  exit 1
fi

release=$(convox builds export "$build" --app "$INPUT_APP" | convox builds import --app "$INPUT_DESTINATIONAPP" --rack "$INPUT_DESTINATIONRACK")

if [ -z "$release" ]; then
  echo "::error::Migration failed — no release ID returned"
  exit 1
fi

write_output "RELEASE" "$release"
persist_env "RELEASE" "$release"
