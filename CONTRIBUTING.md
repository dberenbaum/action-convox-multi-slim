# Contributing to action-convox-multi-slim

## Development Setup

1. Clone the repository
2. Install [ShellCheck](https://www.shellcheck.net/) for linting: `brew install shellcheck`
3. Install [BATS](https://github.com/bats-core/bats-core) for testing: `brew install bats-core`

## Project Structure

```
├── action.yml                  # GitHub Action definition (inputs, outputs, metadata)
├── entrypoint.sh               # Main dispatcher — routes INPUT_ACTION to scripts
├── lib/
│   └── common.sh               # Shared utility functions
├── entrypoint-{action}.sh      # One script per supported action (17 total)
├── tests/
│   ├── common.bats             # BATS tests for shared utilities
│   ├── entrypoints.bats        # BATS tests for the dispatcher and action scripts
│   └── helpers.bash            # Shared test helpers
├── .github/
│   ├── copilot-instructions.md # AI agent guidance
│   └── workflows/
│       ├── ci.yml                 # PR validation (ShellCheck, BATS tests)
│       ├── release.yml            # Computes the next version when a merged PR carries the `release` label
│       ├── release-on-tag.yml     # Creates the GitHub Release when any v* tag is pushed (covers `make release`)
│       ├── build-and-release.yml  # Reusable workflow: bumps version, commits, tags, pushes, updates v3 alias
│       └── auto-update-convox.yml # Daily check for a new Convox CLI version; calls build-and-release.yml
├── Makefile                    # Release automation
└── README.md                   # User documentation
```

## How to Add a New Action

1. **Create the entrypoint script** — `entrypoint-{name}.sh`:
   ```sh
   #!/bin/sh
   set -e
   . "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

   require_input "INPUT_APP" "$INPUT_APP"
   set_rack

   echo "Doing something with $INPUT_APP on $CONVOX_RACK"
   convox your-command --app "$INPUT_APP" --rack "$CONVOX_RACK"
   ```

2. **Register in the dispatcher** — add a case in `entrypoint.sh`:
   ```sh
   "your-action")
     "$ACTION_DIR/entrypoint-your-action.sh"
     ;;
   ```

3. **Update `action.yml`** — add the action name to the `action` input's description list and declare any new inputs/outputs.

4. **Update `README.md`** — add the action to the input/output tables and provide a usage example.

5. **Write tests** — add BATS test cases in `tests/`, including a routing smoke test in `tests/entrypoints.bats` that confirms the dispatcher calls the new script.

## Code Style

- **Shell**: POSIX `sh` compatible (`#!/bin/sh`)
- **Error handling**: Always `set -e`; never use `set -x` (leaks secrets)
- **Variables**: Always double-quote (`"$VAR"`)
- **Errors**: Use `echo "::error::message"` for GitHub-formatted errors
- **Outputs**: Use `write_output "KEY" "$value"` from `common.sh`
- **Inputs**: Validate with `require_input "INPUT_NAME" "$INPUT_NAME"`

## Linting

```sh
shellcheck -x entrypoint*.sh lib/common.sh tests/helpers.bash
```

## Testing

```sh
bats tests/
```

## Releasing

Merged PRs only trigger a release when labelled `release` (a minor version bump). The daily Convox auto-update workflow patch-bumps the version on its own schedule.

For a manual release:

```sh
export VERSION=v3.x.x
make release
```

This will:
1. Write `VERSION` to the `VERSION` file and commit it
2. Create a signed git tag for the exact version, refusing to move it if it already exists
3. Push the branch and the new tag
4. Re-point the `v3` major alias to the new tag (force-pushed)

## Pull Requests

- All PRs must pass CI (ShellCheck, BATS tests)
- Keep one action per entrypoint file
- Update documentation when changing inputs/outputs
- Don't commit `.bak` files (they're in `.gitignore`)
