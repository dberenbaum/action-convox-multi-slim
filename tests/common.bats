#!/usr/bin/env bats

# Tests for lib/common.sh shared utility functions.
# Run with: bats tests/common.bats

setup() {
  # Provide stubs for GITHUB_OUTPUT and GITHUB_ENV
  export GITHUB_OUTPUT=$(mktemp)
  export GITHUB_ENV=$(mktemp)
}

teardown() {
  rm -f "$GITHUB_OUTPUT" "$GITHUB_ENV"
}

# ---------------------------------------------------------------------------
# require_input
# ---------------------------------------------------------------------------

@test "require_input succeeds when value is provided" {
  . lib/common.sh
  run require_input "INPUT_APP" "my-app"
  [ "$status" -eq 0 ]
}

@test "require_input fails when value is empty" {
  . lib/common.sh
  run require_input "INPUT_APP" ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"INPUT_APP is required"* ]]
}

# ---------------------------------------------------------------------------
# set_rack
# ---------------------------------------------------------------------------

@test "set_rack exports CONVOX_RACK" {
  export INPUT_RACK="my-rack"
  . lib/common.sh
  set_rack
  [ "$CONVOX_RACK" = "my-rack" ]
}

@test "set_rack fails when INPUT_RACK is empty" {
  export INPUT_RACK=""
  . lib/common.sh
  run set_rack
  [ "$status" -eq 1 ]
  [[ "$output" == *"INPUT_RACK is required"* ]]
}

# ---------------------------------------------------------------------------
# set_host
# ---------------------------------------------------------------------------

@test "set_host uses INPUT_HOST when provided" {
  export INPUT_HOST="custom.convox.com"
  . lib/common.sh
  set_host
  [ "$CONVOX_HOST" = "custom.convox.com" ]
}

@test "set_host uses default when INPUT_HOST is empty" {
  export INPUT_HOST=""
  . lib/common.sh
  set_host
  [ "$CONVOX_HOST" = "console.convox.com" ]
}

# ---------------------------------------------------------------------------
# set_password
# ---------------------------------------------------------------------------

@test "set_password exports CONVOX_PASSWORD when provided" {
  export INPUT_PASSWORD="secret123"
  . lib/common.sh
  set_password
  [ "$CONVOX_PASSWORD" = "secret123" ]
}

@test "set_password does nothing when INPUT_PASSWORD is empty" {
  unset CONVOX_PASSWORD
  export INPUT_PASSWORD=""
  . lib/common.sh
  set_password
  [ -z "$CONVOX_PASSWORD" ]
}

# ---------------------------------------------------------------------------
# write_output
# ---------------------------------------------------------------------------

@test "write_output writes to GITHUB_OUTPUT" {
  . lib/common.sh
  write_output "RELEASE" "R12345"
  grep -q "RELEASE=R12345" "$GITHUB_OUTPUT"
}

@test "write_output does not write to GITHUB_ENV" {
  . lib/common.sh
  write_output "RELEASE" "R12345"
  ! grep -q "RELEASE=R12345" "$GITHUB_ENV"
}

@test "persist_env writes to GITHUB_ENV" {
  . lib/common.sh
  persist_env "RELEASE" "R12345"
  grep -q "RELEASE=R12345" "$GITHUB_ENV"
}

# ---------------------------------------------------------------------------
# resolve_release
# ---------------------------------------------------------------------------

@test "resolve_release uses INPUT_RELEASE when provided" {
  export INPUT_RELEASE="R99999"
  . lib/common.sh
  resolve_release
  [ "$RELEASE" = "R99999" ]
}

@test "resolve_release keeps existing RELEASE when INPUT_RELEASE is empty" {
  export INPUT_RELEASE=""
  export RELEASE="R11111"
  . lib/common.sh
  resolve_release
  [ "$RELEASE" = "R11111" ]
}

@test "resolve_release fails when required and no release available" {
  export INPUT_RELEASE=""
  unset RELEASE
  . lib/common.sh
  run resolve_release required
  [ "$status" -eq 1 ]
  [[ "$output" == *"Release must"* ]]
}

@test "resolve_release succeeds when required and INPUT_RELEASE is set" {
  export INPUT_RELEASE="R55555"
  . lib/common.sh
  run resolve_release required
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# entrypoint.sh dispatcher
# ---------------------------------------------------------------------------

@test "entrypoint.sh exits 1 for invalid action" {
  export INPUT_ACTION="nonexistent-action"
  run sh entrypoint.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid action"* ]]
}

# ---------------------------------------------------------------------------
# entrypoint-get-scale.sh
# ---------------------------------------------------------------------------

setup_get_scale_stubs() {
  setup_get_scale_stubs_with_ps "0" ""
}

setup_get_scale_stubs_with_ps() {
  scale_running="$1"
  ps_running_line="$2"
  STUB_BIN_DIR=$(mktemp -d)
  cat > "$STUB_BIN_DIR/convox" <<'EOF'
#!/bin/sh
if [ "$1" = "scale" ]; then
  echo "SERVICE DESIRED RUNNING CPU MEMORY"
  echo "web 1 __SCALE_RUNNING__ 256 512"
  exit 0
fi

if [ "$1" = "ps" ]; then
  echo "ID SERVICE STATUS RELEASE STARTED COMMAND"
  __PS_RUNNING_LINE__
  exit 0
fi

echo "unexpected convox command: $1" >&2
exit 1
EOF
  sed -i.bak "s/__SCALE_RUNNING__/$scale_running/g" "$STUB_BIN_DIR/convox"
  rm -f "$STUB_BIN_DIR/convox.bak"
  if [ -n "$ps_running_line" ]; then
    sed -i.bak "s|  __PS_RUNNING_LINE__|  echo \"$ps_running_line\"|g" "$STUB_BIN_DIR/convox"
  else
    sed -i.bak "s|  __PS_RUNNING_LINE__||g" "$STUB_BIN_DIR/convox"
  fi
  rm -f "$STUB_BIN_DIR/convox.bak"
  chmod +x "$STUB_BIN_DIR/convox"
  export PATH="$STUB_BIN_DIR:$PATH"
}

@test "get-scale does not error on zero running processes by default" {
  setup_get_scale_stubs
  export INPUT_APP="my-app"
  export INPUT_SERVICE="web"
  export INPUT_RACK="my-rack"
  export INPUT_ERRORONZEROSCALE="false"

  run sh entrypoint-get-scale.sh

  [ "$status" -eq 0 ]
  grep -q "RUNNING_PROCESSES=0" "$GITHUB_OUTPUT"
  grep -q "SCALING_EVENT=true" "$GITHUB_OUTPUT"
}

@test "get-scale errors on zero running processes when errorOnZeroScale is true" {
  setup_get_scale_stubs
  export INPUT_APP="my-app"
  export INPUT_SERVICE="web"
  export INPUT_RACK="my-rack"
  export INPUT_ERRORONZEROSCALE="true"

  run sh entrypoint-get-scale.sh

  [ "$status" -eq 1 ]
  [[ "$output" == *"No running processes found"* ]]
}

@test "get-scale succeeds when at least one running process exists" {
  setup_get_scale_stubs_with_ps "1" "abc web running R12345 1m worker"

  export INPUT_APP="my-app"
  export INPUT_SERVICE="web"
  export INPUT_RACK="my-rack"
  export INPUT_ERRORONZEROSCALE="true"

  run sh entrypoint-get-scale.sh

  [ "$status" -eq 0 ]
  grep -q "RUNNING_PROCESSES=1" "$GITHUB_OUTPUT"
}

@test "get-scale fails when service scale row is missing" {
  setup_get_scale_stubs_with_ps "0" ""

  export INPUT_APP="my-app"
  export INPUT_SERVICE="worker"
  export INPUT_RACK="my-rack"
  export INPUT_ERRORONZEROSCALE="false"

  run sh entrypoint-get-scale.sh

  [ "$status" -eq 1 ]
  [[ "$output" == *"No scale row found for service worker"* ]]
}
