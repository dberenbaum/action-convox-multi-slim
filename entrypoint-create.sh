#!/bin/sh
set -e
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

require_input "INPUT_APP" "$INPUT_APP"
set_rack

# Idempotent: skip creation if the app already exists (so re-runs don't fail).
# CREATED output is "true" only when this step created the app, letting callers
# run one-time setup (e.g. app params) only on first creation.
if convox apps info "$INPUT_APP" --rack "$CONVOX_RACK" >/dev/null 2>&1; then
  echo "App $INPUT_APP already exists on $CONVOX_RACK"
  write_output "CREATED" "false"
else
  echo "Creating App $INPUT_APP on $CONVOX_RACK"
  convox apps create "$INPUT_APP" --rack "$CONVOX_RACK" --wait
  write_output "CREATED" "true"
fi
