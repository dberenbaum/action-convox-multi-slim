#!/usr/bin/env bats

# Characterization tests for entrypoint.sh (dispatcher) and the
# entrypoint-find-build.sh / entrypoint-find-release.sh scripts.
# Run with: bats tests/entrypoints.bats

load helpers

setup() {
  export GITHUB_OUTPUT=$(mktemp)
  export GITHUB_ENV=$(mktemp)
}

teardown() {
  rm -f "$GITHUB_OUTPUT" "$GITHUB_ENV"
  teardown_stub_convox
}

# ---------------------------------------------------------------------------
# entrypoint.sh dispatcher routing
# ---------------------------------------------------------------------------

@test "dispatcher routes create to convox apps create" {
  stub_convox 'exit 0'
  export INPUT_ACTION="create"
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"

  run sh entrypoint.sh

  [ "$status" -eq 0 ]
  grep -q "^apps create my-app" "$CONVOX_CALLS"
}

@test "dispatcher routes scale to convox scale" {
  stub_convox 'exit 0'
  export INPUT_ACTION="scale"
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_SERVICE="web"
  export INPUT_COUNT="2"

  run sh entrypoint.sh

  [ "$status" -eq 0 ]
  grep -q "scale web --count=2" "$CONVOX_CALLS"
}

@test "dispatcher routes rack-param to convox rack params set" {
  stub_convox 'exit 0'
  export INPUT_ACTION="rack-param"
  export INPUT_RACK="my-rack"
  export INPUT_PARAMNAME="foo"
  export INPUT_PARAMVALUE="bar"

  run sh entrypoint.sh

  [ "$status" -eq 0 ]
  grep -q "rack params set foo=bar" "$CONVOX_CALLS"
}

@test "dispatcher propagates failure when a required input is missing" {
  export INPUT_ACTION="create"
  unset INPUT_APP

  run sh entrypoint.sh

  [ "$status" -eq 1 ]
  [[ "$output" == *"INPUT_APP is required"* ]]
}

# ---------------------------------------------------------------------------
# entrypoint-find-build.sh
# ---------------------------------------------------------------------------

stub_builds_table() {
  stub_convox '
if [ "$1" = "builds" ]; then
  echo "ID          STATUS    RELEASE      STARTED     ELAPSED  DESCRIPTION"
  echo "BAAAAAAAAA  complete  RAAAAAAAAA   1 hour ago  2m       Build one"
  echo "BBBBBBBBBB  complete  RBBBBBBBBB   2 hours ago 2m       Build two"
  exit 0
fi
exit 1'
}

@test "find-build matches a specific description" {
  stub_builds_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="Build two"

  run sh entrypoint-find-build.sh

  [ "$status" -eq 0 ]
  grep -q "BUILD=BBBBBBBBBB" "$GITHUB_OUTPUT"
}

@test "find-build returns the first match when multiple rows match" {
  stub_builds_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="Build"

  run sh entrypoint-find-build.sh

  [ "$status" -eq 0 ]
  grep -q "BUILD=BAAAAAAAAA" "$GITHUB_OUTPUT"
}

# characterization: plan 005 changes this to warn on no match
@test "find-build writes an empty output and exits 0 when nothing matches" {
  stub_builds_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="nope"

  run sh entrypoint-find-build.sh

  [ "$status" -eq 0 ]
  grep -q "^BUILD=$" "$GITHUB_OUTPUT"
}

@test "find-build fails when no description is available" {
  stub_builds_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION=""
  unset DESCRIPTION

  run sh entrypoint-find-build.sh

  [ "$status" -eq 1 ]
  [[ "$output" == *"Description must be passed"* ]]
}

@test "find-build falls back to the DESCRIPTION env var" {
  stub_builds_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION=""
  export DESCRIPTION="Build one"

  run sh entrypoint-find-build.sh

  [ "$status" -eq 0 ]
  grep -q "BUILD=BAAAAAAAAA" "$GITHUB_OUTPUT"
}

# ---------------------------------------------------------------------------
# entrypoint-find-release.sh
# ---------------------------------------------------------------------------

stub_releases_table() {
  stub_convox '
if [ "$1" = "releases" ]; then
  echo "ID          STATUS    BUILD        CREATED     DESCRIPTION"
  echo "RAAAAAAAAA  complete  BAAAAAAAAA   1 hour ago  Build one"
  echo "RBBBBBBBBB  complete  BBBBBBBBBB   2 hours ago Build two"
  exit 0
fi
exit 1'
}

@test "find-release matches a specific description" {
  stub_releases_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="Build two"

  run sh entrypoint-find-release.sh

  [ "$status" -eq 0 ]
  grep -q "RELEASE=RBBBBBBBBB" "$GITHUB_OUTPUT"
}

@test "find-release returns the first match when multiple rows match" {
  stub_releases_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="Build"

  run sh entrypoint-find-release.sh

  [ "$status" -eq 0 ]
  grep -q "RELEASE=RAAAAAAAAA" "$GITHUB_OUTPUT"
}

# characterization: plan 005 changes this to warn on no match
@test "find-release writes an empty output and exits 0 when nothing matches" {
  stub_releases_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="nope"

  run sh entrypoint-find-release.sh

  [ "$status" -eq 0 ]
  grep -q "^RELEASE=$" "$GITHUB_OUTPUT"
}

@test "find-release fails when no description is available" {
  stub_releases_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION=""
  unset DESCRIPTION

  run sh entrypoint-find-release.sh

  [ "$status" -eq 1 ]
  [[ "$output" == *"Description must be passed"* ]]
}

@test "find-release falls back to the DESCRIPTION env var" {
  stub_releases_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION=""
  export DESCRIPTION="Build one"

  run sh entrypoint-find-release.sh

  [ "$status" -eq 0 ]
  grep -q "RELEASE=RAAAAAAAAA" "$GITHUB_OUTPUT"
}

# ---------------------------------------------------------------------------
# entrypoint-run.sh (plan 004: command passed as a single argv element)
# ---------------------------------------------------------------------------

@test "run: command with single quotes survives intact" {
  stub_convox 'exit 0'
  stub_script
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_SERVICE="web"
  export INPUT_COMMAND="echo 'it's done'"

  run sh entrypoint-run.sh

  [ "$status" -eq 0 ]
  grep -F "it's done" "$CONVOX_CALLS"
}

@test "run: injection payload stays inert" {
  stub_convox 'exit 0'
  stub_script
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_SERVICE="web"
  export INPUT_COMMAND="x\"; touch $BATS_TEST_TMPDIR/pwned; echo \""

  run sh entrypoint-run.sh

  [ "$status" -eq 0 ]
  grep -F "touch $BATS_TEST_TMPDIR/pwned" "$CONVOX_CALLS"
  [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
}

@test "run: includes --release when INPUT_RELEASE is set" {
  stub_convox 'exit 0'
  stub_script
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_SERVICE="web"
  export INPUT_COMMAND="ls"
  export INPUT_RELEASE="R123"

  run sh entrypoint-run.sh

  [ "$status" -eq 0 ]
  grep -q -- "--release R123" "$CONVOX_CALLS"
}

@test "run: omits --release when INPUT_RELEASE is not set" {
  stub_convox 'exit 0'
  stub_script
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_SERVICE="web"
  export INPUT_COMMAND="ls"

  run sh entrypoint-run.sh

  [ "$status" -eq 0 ]
  ! grep -q -- "--release" "$CONVOX_CALLS"
}

@test "run: propagates convox's exit code" {
  stub_convox 'exit 7'
  stub_script
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_SERVICE="web"
  export INPUT_COMMAND="ls"

  run sh entrypoint-run.sh

  [ "$status" -eq 7 ]
}
