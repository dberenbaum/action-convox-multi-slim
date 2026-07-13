#!/bin/sh
set -e
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

require_input "INPUT_APP" "$INPUT_APP"
set_rack

if [ -n "$INPUT_DESCRIPTION" ]; then
  export DESCRIPTION="$INPUT_DESCRIPTION"
fi

if [ -z "$DESCRIPTION" ]; then
  echo "::error::Description must be passed as input"
  exit 1
fi

echo "Finding first release with description '$DESCRIPTION' for $INPUT_APP on $CONVOX_RACK"
# shellcheck disable=SC2153 # RELEASE is an output name, not a misspelling of 'release'
release=$(convox releases --app "$INPUT_APP" --limit 100 | grep -F -- "$DESCRIPTION" | awk 'NR==1 {print $1}')

if [ -z "$release" ]; then
  echo "::warning::No release found matching description '$DESCRIPTION' for $INPUT_APP (searched last 100 releases)"
fi

write_output "RELEASE" "$release"
