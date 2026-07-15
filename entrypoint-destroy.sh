#!/bin/sh
set -e
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

require_input "INPUT_APP" "$INPUT_APP"
set_rack

# Idempotent: only delete if the app exists, so tearing down a PR that never
# had an app is a no-op rather than an error. DESTROYED output reflects whether
# a deletion actually happened.
if convox apps info "$INPUT_APP" --rack "$CONVOX_RACK" >/dev/null 2>&1; then
  echo "Destroying App $INPUT_APP on $CONVOX_RACK"
  convox apps delete "$INPUT_APP" --rack "$CONVOX_RACK" --wait
  write_output "DESTROYED" "true"
else
  echo "App $INPUT_APP does not exist on $CONVOX_RACK; nothing to destroy"
  write_output "DESTROYED" "false"
fi
