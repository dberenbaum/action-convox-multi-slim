# Contributing to action-convox-multi-slim

## Development Setup

1. Clone the repository
2. Ensure you have Docker installed and running
3. Install [ShellCheck](https://www.shellcheck.net/) for linting: `brew install shellcheck`
4. Install [BATS](https://github.com/bats-core/bats-core) for testing: `brew install bats-core`
5. Install [hadolint](https://github.com/hadolint/hadolint) for Dockerfile linting: `brew install hadolint`

## Project Structure

```
├── action.yml                  # GitHub Action definition (inputs, outputs, metadata)
├── Dockerfile                  # Container image build (Ubuntu 22.04 + Convox CLI)
├── entrypoint.sh               # Main dispatcher — routes INPUT_ACTION to scripts
├── lib/
│   └── common.sh               # Shared utility functions
├── entrypoint-{action}.sh      # One script per supported action (16 total)
├── tests/
│   └── common.bats             # BATS tests for shared utilities
├── .github/
│   ├── copilot-instructions.md # AI agent guidance
│   └── workflows/
│       ├── ci.yml              # PR validation (ShellCheck, hadolint, tests)
│       └── release.yml         # Tag-triggered GitHub Release
├── Makefile                    # Release automation
└── README.md                   # User documentation
```

## How to Add a New Action

1. **Create the entrypoint script** — `entrypoint-{name}.sh`:
   ```sh
   #!/bin/sh
   set -e
   . /lib/common.sh

   require_input "INPUT_APP" "$INPUT_APP"
   set_rack

   echo "Doing something with $INPUT_APP on $CONVOX_RACK"
   convox your-command --app "$INPUT_APP" --rack "$CONVOX_RACK"
   ```

2. **Register in the dispatcher** — add a case in `entrypoint.sh`:
   ```sh
   "your-action")
     /entrypoint-your-action.sh
     ;;
   ```

3. **Update `action.yml`** — add the action name to `inputs.action.options` and declare any new inputs/outputs.

4. **Update `README.md`** — add the action to the input/output tables and provide a usage example.

5. **Write tests** — add BATS test cases in `tests/`.

## Code Style

- **Shell**: POSIX `sh` compatible (`#!/bin/sh`)
- **Error handling**: Always `set -e`; never use `set -x` (leaks secrets)
- **Variables**: Always double-quote (`"$VAR"`)
- **Errors**: Use `echo "::error::message"` for GitHub-formatted errors
- **Outputs**: Use `write_output "KEY" "$value"` from `common.sh`
- **Inputs**: Validate with `require_input "INPUT_NAME" "$INPUT_NAME"`

## Linting

```sh
# Shell scripts
shellcheck entrypoint*.sh lib/common.sh

# Dockerfile
hadolint Dockerfile
```

## Testing

```sh
bats tests/
```

## Releasing

Merged PRs only trigger a release when labelled `release` (a minor version bump). The daily Convox auto-update workflow patch-bumps the version on its own schedule.

For a manual release:

```sh
export VERSION=v1.x.x
make release
```

This will:
1. Check Docker daemon and Docker Hub login
2. Update version references in `action.yml` and `Dockerfile`
3. Commit, build/push Docker image, create signed git tag, push
4. Refuse to move an already-published exact version tag, but re-point the `v3` major alias to the new tag

## Pull Requests

- All PRs must pass CI (ShellCheck, hadolint, BATS tests)
- Keep one action per entrypoint file
- Update documentation when changing inputs/outputs
- Don't commit `.bak` files (they're in `.gitignore`)
