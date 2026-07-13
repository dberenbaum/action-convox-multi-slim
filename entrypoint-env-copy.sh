#!/bin/sh
set -e
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

# Copy the environment of one app onto another, optionally excluding some keys.
# Source app: INPUT_APP / INPUT_RACK. Destination: INPUT_DESTINATIONAPP /
# INPUT_DESTINATIONRACK (defaults to the source rack). INPUT_EXCLUDE is a
# space- or newline-separated list of keys to drop (matched as whole names).
#
# The env is streamed source -> dest via a temp file that never leaves the
# runner's temp dir, so secrets are never printed, logged, or exposed as an
# output.
require_input "INPUT_APP" "$INPUT_APP"
require_input "INPUT_DESTINATIONAPP" "$INPUT_DESTINATIONAPP"
set_rack

dest_rack="${INPUT_DESTINATIONRACK:-$CONVOX_RACK}"
echo "Copying env from $INPUT_APP ($CONVOX_RACK) to $INPUT_DESTINATIONAPP ($dest_rack)"

tmp=$(mktemp)
# shellcheck disable=SC2064
trap "rm -f \"$tmp\"" EXIT
convox env -a "$INPUT_APP" --rack "$CONVOX_RACK" > "$tmp"
if [ ! -s "$tmp" ]; then
  echo "::error::No environment retrieved from source app $INPUT_APP"
  exit 1
fi

# Build grep -v arguments from the exclude list (match KEY= at line start).
set -f
# shellcheck disable=SC2086
set -- $INPUT_EXCLUDE
set +f
grep_args=""
for key in "$@"; do
  [ -n "$key" ] || continue
  grep_args="$grep_args -e ^${key}="
done

if [ -n "$grep_args" ]; then
  # shellcheck disable=SC2086
  grep -v $grep_args "$tmp" | convox env set -a "$INPUT_DESTINATIONAPP" --rack "$dest_rack"
else
  convox env set -a "$INPUT_DESTINATIONAPP" --rack "$dest_rack" < "$tmp"
fi
