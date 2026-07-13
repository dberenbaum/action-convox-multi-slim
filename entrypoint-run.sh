#!/bin/sh
set -e
. "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

require_input "INPUT_APP" "$INPUT_APP"
require_input "INPUT_SERVICE" "$INPUT_SERVICE"
require_input "INPUT_COMMAND" "$INPUT_COMMAND"
set_rack
resolve_release ""  # optional — no arg means not required

if [ -n "$RELEASE" ]; then
  echo "Running command on $INPUT_SERVICE - $INPUT_APP for release $RELEASE"
else
  echo "Running command on $INPUT_SERVICE - $INPUT_APP for the latest release"
fi

# Use 'script' to allocate a pseudo-TTY. This works around a GitHub Actions
# runner change which made terminals non-interactive, breaking convox run's
# WebSocket/SPDY connection that relies on TTY detection.
#
# Without a real PTY, the convox CLI detects a non-interactive stdin, disables
# TTY mode, and the SPDY stream to the Kubernetes pod hangs or fails.
#
# Flags: -q (quiet), -e (return child exit code), -c (run command)
# /dev/null discards the typescript recording file.
#
# The command is passed to the inner shell via environment variables and a
# fixed heredoc script, so user input is never parsed as shell syntax.
RUN_SCRIPT=$(mktemp)
cat > "$RUN_SCRIPT" <<'EOF'
#!/bin/sh
set -e
if [ -n "$RELEASE" ]; then
  exec convox run "$INPUT_SERVICE" "$INPUT_COMMAND" --release "$RELEASE" --app "$INPUT_APP" --rack "$CONVOX_RACK" --timeout 3600
else
  exec convox run "$INPUT_SERVICE" "$INPUT_COMMAND" --app "$INPUT_APP" --rack "$CONVOX_RACK" --timeout 3600
fi
EOF

set +e
script -qec "sh $RUN_SCRIPT" /dev/null
exit_code=$?
set -e
rm -f "$RUN_SCRIPT"

echo "Command completed with exit code: $exit_code"
exit $exit_code