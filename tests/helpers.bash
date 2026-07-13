# Shared bats test helpers for stubbing the `convox` CLI.
#
# stub_convox <script-body>
# Creates a fake `convox` on PATH whose behaviour is <script-body> (sh syntax).
# The stub also appends its full argv to $CONVOX_CALLS (one line per call).
stub_convox() {
  STUB_BIN_DIR=$(mktemp -d)
  export CONVOX_CALLS="$STUB_BIN_DIR/calls.log"
  {
    echo '#!/bin/sh'
    echo 'echo "$@" >> "$CONVOX_CALLS"'
    printf '%s\n' "$1"
  } > "$STUB_BIN_DIR/convox"
  chmod +x "$STUB_BIN_DIR/convox"
  export PATH="$STUB_BIN_DIR:$PATH"
}

teardown_stub_convox() {
  if [ -n "$STUB_BIN_DIR" ]; then
    rm -rf "$STUB_BIN_DIR"
  fi
}

# stub_script — fake util-linux `script` that just runs the -c command string.
# Mirrors `script -qec "cmd" /dev/null` argv: $1=-qec $2=cmd $3=/dev/null
stub_script() {
  cat > "$STUB_BIN_DIR/script" <<'EOF'
#!/bin/sh
sh -c "$2"
exit $?
EOF
  chmod +x "$STUB_BIN_DIR/script"
}
