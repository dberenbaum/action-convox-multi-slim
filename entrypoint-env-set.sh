#!/bin/sh
set -e
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

require_input "INPUT_APP" "$INPUT_APP"
require_input "INPUT_ENV" "$INPUT_ENV"
set_rack

echo "Setting environment variables for app $INPUT_APP on $CONVOX_RACK"

# Newline-separated pairs allow values containing spaces; the legacy
# space-separated form still works for single-line input.
case "$INPUT_ENV" in
  *"$(printf '\n')"*)
    old_ifs="$IFS"
    IFS="$(printf '\n_')"; IFS="${IFS%_}"   # IFS = newline only
    set -f
    # shellcheck disable=SC2086
    set -- $INPUT_ENV
    set +f
    IFS="$old_ifs"
    ;;
  *)
    set -f
    # shellcheck disable=SC2086
    set -- $INPUT_ENV
    set +f
    ;;
esac

# Drop empty arguments produced by blank/trailing lines
old_argc=$#
i=0
while [ "$i" -lt "$old_argc" ]; do
  pair="$1"; shift
  if [ -n "$pair" ]; then set -- "$@" "$pair"; fi
  i=$((i+1))
done

convox env set -a "$INPUT_APP" --rack "$CONVOX_RACK" "$@"
