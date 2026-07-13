#!/bin/sh
# common.sh — Shared utility functions for all entrypoint scripts.
# Source this file at the top of each entrypoint:
#   . "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

# Default Convox console host
DEFAULT_CONVOX_HOST="console.convox.com"

# ---------------------------------------------------------------------------
# set_rack — Export CONVOX_RACK from INPUT_RACK
#   Usage: set_rack
#   Requires: INPUT_RACK
# ---------------------------------------------------------------------------
set_rack() {
  if [ -z "$INPUT_RACK" ]; then
    echo "::error::INPUT_RACK is required but was not provided"
    exit 1
  fi
  export CONVOX_RACK="$INPUT_RACK"
}

# ---------------------------------------------------------------------------
# set_host — Export CONVOX_HOST from INPUT_HOST (or default)
#   Usage: set_host
# ---------------------------------------------------------------------------
set_host() {
  if [ -n "$INPUT_HOST" ]; then
    export CONVOX_HOST="$INPUT_HOST"
  else
    export CONVOX_HOST="$DEFAULT_CONVOX_HOST"
  fi
}

# ---------------------------------------------------------------------------
# set_password — Export CONVOX_PASSWORD from INPUT_PASSWORD
#   Usage: set_password
# ---------------------------------------------------------------------------
set_password() {
  if [ -n "$INPUT_PASSWORD" ]; then
    export CONVOX_PASSWORD="$INPUT_PASSWORD"
  fi
}

# ---------------------------------------------------------------------------
# require_input — Validate that a required input variable is set
#   Usage: require_input "INPUT_APP" "$INPUT_APP"
# ---------------------------------------------------------------------------
require_input() {
  _ri_name="$1"
  _ri_value="$2"
  if [ -z "$_ri_value" ]; then
    echo "::error::${_ri_name} is required but was not provided"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# write_output — Write a key=value pair to GITHUB_OUTPUT
#   Usage: write_output "RELEASE" "$release"
# ---------------------------------------------------------------------------
write_output() {
  _wo_key="$1"
  _wo_value="$2"
  echo "${_wo_key}=${_wo_value}" >> "$GITHUB_OUTPUT"
}

# ---------------------------------------------------------------------------
# persist_env — Persist a key=value pair to GITHUB_ENV for later steps.
#   Only use for values later steps genuinely read (currently: RELEASE).
#   Usage: persist_env "RELEASE" "$release"
# ---------------------------------------------------------------------------
persist_env() {
  _pe_key="$1"
  _pe_value="$2"
  echo "${_pe_key}=${_pe_value}" >> "$GITHUB_ENV"
}

# ---------------------------------------------------------------------------
# resolve_release — Set RELEASE from INPUT_RELEASE if provided, otherwise
#   use any RELEASE already in the environment (from a prior build step).
#   Optionally require it if first argument is "required".
#   Usage: resolve_release [required]
# ---------------------------------------------------------------------------
resolve_release() {
  if [ -n "$INPUT_RELEASE" ]; then
    export RELEASE="$INPUT_RELEASE"
  fi
  if [ "$1" = "required" ] && [ -z "$RELEASE" ]; then
    echo "::error::Release must either be passed as input or set by running a build step first"
    exit 1
  fi
}
