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
  # create is idempotent: it only runs `apps create` when `apps info` shows the
  # app is absent, so the stub must report the app as not found.
  stub_convox 'if [ "$1 $2" = "apps info" ]; then exit 1; fi; exit 0'
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

@test "find-build writes an empty output and exits 0 when nothing matches" {
  stub_builds_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="nope"

  run sh entrypoint-find-build.sh

  [ "$status" -eq 0 ]
  grep -q "^BUILD=$" "$GITHUB_OUTPUT"
  [[ "$output" == *"::warning::No build found"* ]]
}

stub_builds_table_with_regex_chars() {
  stub_convox '
if [ "$1" = "builds" ]; then
  echo "ID          STATUS    RELEASE      STARTED     ELAPSED  DESCRIPTION"
  echo "BAAAAAAAAA  complete  RAAAAAAAAA   1 hour ago  2m       Deploy 1x2y3"
  echo "BBBBBBBBBB  complete  RBBBBBBBBB   2 hours ago 2m       Deploy 1.2.3"
  exit 0
fi
exit 1'
}

@test "find-build matches description literally, not as a regex" {
  stub_builds_table_with_regex_chars
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="Deploy 1.2.3"

  run sh entrypoint-find-build.sh

  [ "$status" -eq 0 ]
  grep -q "BUILD=BBBBBBBBBB" "$GITHUB_OUTPUT"
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

@test "find-release writes an empty output and exits 0 when nothing matches" {
  stub_releases_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="nope"

  run sh entrypoint-find-release.sh

  [ "$status" -eq 0 ]
  grep -q "^RELEASE=$" "$GITHUB_OUTPUT"
  [[ "$output" == *"::warning::No release found"* ]]
}

stub_releases_table_with_regex_chars() {
  stub_convox '
if [ "$1" = "releases" ]; then
  echo "ID          STATUS    BUILD        CREATED     DESCRIPTION"
  echo "RAAAAAAAAA  complete  BAAAAAAAAA   1 hour ago  Deploy 1x2y3"
  echo "RBBBBBBBBB  complete  BBBBBBBBBB   2 hours ago Deploy 1.2.3"
  exit 0
fi
exit 1'
}

@test "find-release matches description literally, not as a regex" {
  stub_releases_table_with_regex_chars
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="Deploy 1.2.3"

  run sh entrypoint-find-release.sh

  [ "$status" -eq 0 ]
  grep -q "RELEASE=RBBBBBBBBB" "$GITHUB_OUTPUT"
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

# ---------------------------------------------------------------------------
# entrypoint-build-migrate.sh
# ---------------------------------------------------------------------------

stub_migrate_builds_table() {
  stub_convox '
case "$1 $2" in
  "builds export")
    echo "RNEWRELEASE"
    exit 0
    ;;
  "builds import")
    cat > /dev/null
    echo "RNEWRELEASE"
    exit 0
    ;;
esac
if [ "$1" = "builds" ]; then
  echo "ID          STATUS    RELEASE      STARTED     ELAPSED  DESCRIPTION"
  echo "BAAAAAAAAA  failed    RAAAAAAAAA   1 hour ago  2m       almost complete"
  echo "BBBBBBBBBB  complete  RBBBBBBBBB   2 hours ago 2m       Build two"
  exit 0
fi
exit 1'
}

@test "build-migrate selects the build whose status column is complete" {
  stub_migrate_builds_table
  export INPUT_APP="my-app"
  export INPUT_DESTINATIONAPP="my-app-dest"
  export INPUT_DESTINATIONRACK="dest-rack"
  export INPUT_RACK="my-rack"

  run sh entrypoint-build-migrate.sh

  [ "$status" -eq 0 ]
  grep -q "builds export BBBBBBBBBB" "$CONVOX_CALLS"
  grep -q "RELEASE=RNEWRELEASE" "$GITHUB_OUTPUT"
}

# ---------------------------------------------------------------------------
# entrypoint-env-set.sh / entrypoint-build.sh — space-safe arguments
# ---------------------------------------------------------------------------

@test "env-set: legacy space-separated form sets multiple pairs" {
  # argc assertion proves A=1 and B=2 arrive as SEPARATE arguments — the
  # flattened calls log alone cannot see argument boundaries.
  stub_convox 'echo "argc=$#" >> "$CONVOX_CALLS"'
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_ENV="A=1 B=2"

  run sh entrypoint-env-set.sh

  [ "$status" -eq 0 ]
  # argv is: env set -a my-app --rack my-rack A=1 B=2 = 8 args
  grep -q "^argc=8$" "$CONVOX_CALLS"
  grep -F -q "A=1 B=2" "$CONVOX_CALLS"
}

@test "env-set: newline-separated form keeps a spaced value as one argument" {
  # First line of CONVOX_CALLS is the flattened argv (from the stub's
  # recording line); second line is this body's own "argc=$#" output.
  stub_convox 'echo "argc=$#" >> "$CONVOX_CALLS"'
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_ENV="$(printf 'A=1\nMSG=hello world')"

  run sh entrypoint-env-set.sh

  [ "$status" -eq 0 ]
  # argv is: env set -a my-app --rack my-rack A=1 "MSG=hello world" = 8 args
  grep -q "^argc=8$" "$CONVOX_CALLS"
  grep -F -q "MSG=hello world" "$CONVOX_CALLS"
}

@test "env-set: glob characters in a value are passed literally" {
  stub_convox 'exit 0'
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_ENV='PATTERN=*'

  run sh entrypoint-env-set.sh

  [ "$status" -eq 0 ]
  grep -F -q "PATTERN=*" "$CONVOX_CALLS"
}

@test "build: manifest path with a space reaches convox as one argument" {
  # Stub echoes a release id so the script's empty-release check passes.
  stub_convox 'echo "argc=$#" >> "$CONVOX_CALLS"; echo R123'
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="test-desc"
  export INPUT_MANIFEST="my dir/convox.yml"

  run sh entrypoint-build.sh

  [ "$status" -eq 0 ]
  # argv is: build --app my-app --description test-desc --id -m "my dir/convox.yml" = 8 args
  grep -q "^argc=8$" "$CONVOX_CALLS"
  grep -F -q "my dir/convox.yml" "$CONVOX_CALLS"
}

@test "build: --no-cache and --external flags are appended when requested" {
  stub_convox 'echo R123'
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="test-desc"
  export INPUT_CACHED="false"
  export INPUT_EXTERNAL="true"

  run sh entrypoint-build.sh

  [ "$status" -eq 0 ]
  grep -q -- "--no-cache" "$CONVOX_CALLS"
  grep -q -- "--external" "$CONVOX_CALLS"
}

@test "build: each buildArgs pair is passed as a separate --build-args flag" {
  # argc assertion proves both pairs arrive as separate --build-args flags.
  stub_convox 'echo "argc=$#" >> "$CONVOX_CALLS"; echo R123'
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="test-desc"
  export INPUT_BUILDARGS="FOO=1 BAR=2"

  run sh entrypoint-build.sh

  [ "$status" -eq 0 ]
  # argv: build --app my-app --description test-desc --id --build-args FOO=1 --build-args BAR=2 = 10
  grep -q "^argc=10$" "$CONVOX_CALLS"
  grep -F -q "FOO=1" "$CONVOX_CALLS"
  grep -F -q "BAR=2" "$CONVOX_CALLS"
}

@test "deploy: each buildArgs pair is passed as a separate --build-args flag" {
  stub_convox 'echo "argc=$#" >> "$CONVOX_CALLS"'
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="test-desc"
  export INPUT_BUILDARGS="FOO=1 BAR=2"

  run sh entrypoint-deploy.sh

  [ "$status" -eq 0 ]
  # argv: deploy --app my-app --description test-desc --build-args FOO=1 --build-args BAR=2 --wait = 10
  grep -q "^argc=10$" "$CONVOX_CALLS"
  grep -F -q "FOO=1" "$CONVOX_CALLS"
  grep -F -q "BAR=2" "$CONVOX_CALLS"
}

# ---------------------------------------------------------------------------
# GITHUB_OUTPUT / GITHUB_ENV channel split (plan 009)
# ---------------------------------------------------------------------------

@test "find-release: RELEASE reaches both GITHUB_OUTPUT and GITHUB_ENV (promote auto-detect survives)" {
  stub_releases_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="Build two"

  run sh entrypoint-find-release.sh

  [ "$status" -eq 0 ]
  grep -q "RELEASE=" "$GITHUB_OUTPUT"
  grep -q "RELEASE=" "$GITHUB_ENV"
}

@test "find-build: BUILD does not leak into GITHUB_ENV" {
  stub_builds_table
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_DESCRIPTION="Build two"

  run sh entrypoint-find-build.sh

  [ "$status" -eq 0 ]
  grep -q "BUILD=" "$GITHUB_OUTPUT"
  ! grep -q "BUILD=" "$GITHUB_ENV"
}

# ---------------------------------------------------------------------------
# entrypoint-create.sh — idempotent create + CREATED output
# ---------------------------------------------------------------------------

@test "create: creates the app and reports CREATED=true when it is absent" {
  stub_convox 'if [ "$1 $2" = "apps info" ]; then exit 1; fi; exit 0'
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"

  run sh entrypoint-create.sh

  [ "$status" -eq 0 ]
  grep -q "^apps create my-app" "$CONVOX_CALLS"
  grep -q "^CREATED=true$" "$GITHUB_OUTPUT"
}

@test "create: skips creation and reports CREATED=false when the app exists" {
  stub_convox 'if [ "$1 $2" = "apps info" ]; then exit 0; fi; exit 0'
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"

  run sh entrypoint-create.sh

  [ "$status" -eq 0 ]
  ! grep -q "^apps create" "$CONVOX_CALLS"
  grep -q "^CREATED=false$" "$GITHUB_OUTPUT"
}

# ---------------------------------------------------------------------------
# entrypoint-destroy.sh — idempotent destroy + DESTROYED output
# ---------------------------------------------------------------------------

@test "destroy: deletes the app with --wait and reports DESTROYED=true when it exists" {
  stub_convox 'if [ "$1 $2" = "apps info" ]; then exit 0; fi; exit 0'
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"

  run sh entrypoint-destroy.sh

  [ "$status" -eq 0 ]
  grep -q "^apps delete my-app --rack my-rack --wait$" "$CONVOX_CALLS"
  grep -q "^DESTROYED=true$" "$GITHUB_OUTPUT"
}

@test "destroy: is a no-op reporting DESTROYED=false when the app is absent" {
  stub_convox 'if [ "$1 $2" = "apps info" ]; then exit 1; fi; exit 0'
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"

  run sh entrypoint-destroy.sh

  [ "$status" -eq 0 ]
  ! grep -q "^apps delete" "$CONVOX_CALLS"
  grep -q "^DESTROYED=false$" "$GITHUB_OUTPUT"
}

# ---------------------------------------------------------------------------
# entrypoint-app-param.sh
# ---------------------------------------------------------------------------

@test "dispatcher routes app-param to convox apps params set" {
  stub_convox 'exit 0'
  export INPUT_ACTION="app-param"
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_PARAMS="BuildCpu=2000 BuildMem=4096"

  run sh entrypoint.sh

  [ "$status" -eq 0 ]
  grep -q "apps params set BuildCpu=2000 BuildMem=4096 -a my-app --rack my-rack" "$CONVOX_CALLS"
}

@test "app-param: newline-separated form keeps a spaced value as one argument" {
  stub_convox 'echo "argc=$#" >> "$CONVOX_CALLS"'
  export INPUT_APP="my-app"
  export INPUT_RACK="my-rack"
  export INPUT_PARAMS="$(printf 'BuildCpu=2000\nBuildLabels=convox.io/label=platform tier=spot')"

  run sh entrypoint-app-param.sh

  [ "$status" -eq 0 ]
  # argv is: apps params set BuildCpu=2000 "BuildLabels=..." -a my-app --rack my-rack = 9 args
  grep -q "^argc=9$" "$CONVOX_CALLS"
  grep -F -q "BuildLabels=convox.io/label=platform tier=spot" "$CONVOX_CALLS"
}

# ---------------------------------------------------------------------------
# entrypoint-env-copy.sh
# ---------------------------------------------------------------------------

# convox env (read) prints three vars; convox env set records its stdin so the
# test can assert which vars were copied through.
stub_env_copy() {
  export ENV_SET_STDIN="$BATS_TEST_TMPDIR/env-set-stdin"
  stub_convox '
if [ "$1" = "env" ] && [ "$2" = "set" ]; then cat >> "$ENV_SET_STDIN"; exit 0; fi
if [ "$1" = "env" ]; then printf "A=1\nSANDBOX_DATABASE_URL=postgres://secret\nB=2\n"; exit 0; fi
exit 0'
}

@test "env-copy: copies all vars when no exclude is given" {
  stub_env_copy
  export INPUT_APP="source-app"
  export INPUT_DESTINATIONAPP="dest-app"
  export INPUT_RACK="my-rack"

  run sh entrypoint-env-copy.sh

  [ "$status" -eq 0 ]
  grep -q "^A=1$" "$ENV_SET_STDIN"
  grep -q "^SANDBOX_DATABASE_URL=" "$ENV_SET_STDIN"
  grep -q "^B=2$" "$ENV_SET_STDIN"
}

@test "env-copy: drops excluded keys" {
  stub_env_copy
  export INPUT_APP="source-app"
  export INPUT_DESTINATIONAPP="dest-app"
  export INPUT_RACK="my-rack"
  export INPUT_EXCLUDE="SANDBOX_DATABASE_URL"

  run sh entrypoint-env-copy.sh

  [ "$status" -eq 0 ]
  grep -q "^A=1$" "$ENV_SET_STDIN"
  grep -q "^B=2$" "$ENV_SET_STDIN"
  ! grep -q "^SANDBOX_DATABASE_URL=" "$ENV_SET_STDIN"
}

@test "env-copy: fails when the source app has no env" {
  stub_convox '
if [ "$1" = "env" ] && [ "$2" = "set" ]; then cat > /dev/null; exit 0; fi
if [ "$1" = "env" ]; then exit 0; fi
exit 0'
  export INPUT_APP="source-app"
  export INPUT_DESTINATIONAPP="dest-app"
  export INPUT_RACK="my-rack"

  run sh entrypoint-env-copy.sh

  [ "$status" -eq 1 ]
  [[ "$output" == *"No environment retrieved"* ]]
}

@test "dispatcher routes env-copy to entrypoint-env-copy.sh" {
  stub_env_copy
  export INPUT_ACTION="env-copy"
  export INPUT_APP="source-app"
  export INPUT_DESTINATIONAPP="dest-app"
  export INPUT_RACK="my-rack"

  run sh entrypoint.sh

  [ "$status" -eq 0 ]
  grep -q "^A=1$" "$ENV_SET_STDIN"
}

# ---------------------------------------------------------------------------
# action.yml wiring — guards against declaring an input but forgetting to map
# it into the run step's env: block (the entrypoint reads INPUT_<UPPER>).
# ---------------------------------------------------------------------------

@test "action.yml: every declared input is mapped to an INPUT_* env var" {
  inputs=$(awk '/^inputs:/{f=1;next} /^[a-zA-Z]/{f=0} f && /^  [a-zA-Z]/{sub(/:.*/,"",$1); print $1}' action.yml)
  [ -n "$inputs" ]  # sanity: we found some inputs
  missing=""
  for name in $inputs; do
    upper=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')
    grep -q "INPUT_${upper}:" action.yml || missing="$missing $name"
  done
  [ -z "$missing" ] || { echo "inputs declared but not wired to INPUT_* env:$missing"; false; }
}
