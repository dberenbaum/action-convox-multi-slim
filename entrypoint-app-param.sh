#!/bin/sh
set -e
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

# Set one or more app parameters (e.g. BuildCpu, BuildMem). INPUT_PARAMS is a
# space- or newline-separated list of KEY=VALUE pairs; newline separation lets
# a value contain spaces (mirrors env-set).
require_input "INPUT_APP" "$INPUT_APP"
require_input "INPUT_PARAMS" "$INPUT_PARAMS"
set_rack

echo "Setting app params for $INPUT_APP on $CONVOX_RACK"

nl=$(printf '\n_'); nl=${nl%_}
case "$INPUT_PARAMS" in
  *"$nl"*)
    old_ifs="$IFS"
    IFS="$(printf '\n_')"; IFS="${IFS%_}"   # IFS = newline only
    set -f
    # shellcheck disable=SC2086
    set -- $INPUT_PARAMS
    set +f
    IFS="$old_ifs"
    ;;
  *)
    set -f
    # shellcheck disable=SC2086
    set -- $INPUT_PARAMS
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

convox apps params set "$@" -a "$INPUT_APP" --rack "$CONVOX_RACK"
