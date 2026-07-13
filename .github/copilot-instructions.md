# Copilot Instructions for action-convox-multi-slim

## Project Overview

This is a **composite GitHub Action** that wraps the Convox CLI into a single reusable action supporting 17 different commands. It installs the Convox CLI directly on the runner (pinned via the `CONVOX_VERSION` and `CONVOX_SHA256` files, checksum-verified) and uses a dispatcher pattern where `entrypoint.sh` routes the `action` input to individual `entrypoint-{action}.sh` scripts.

## Architecture

```
entrypoint.sh          — Main dispatcher (case switch on INPUT_ACTION)
lib/common.sh          — Shared utility functions (set_rack, write_output, etc.)
entrypoint-{action}.sh — One script per supported Convox command
action.yml             — GitHub Action interface definition (inputs/outputs); installs the pinned Convox CLI, then runs entrypoint.sh
```

## Key Conventions

### Adding a New Action

1. Create `entrypoint-{action-name}.sh` in the project root
2. Start the script with:
   ```sh
   #!/bin/sh
   set -e
   . "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"
   ```
3. Validate required inputs using `require_input "INPUT_NAME" "$INPUT_NAME"`
4. Call `set_rack` if the action needs `CONVOX_RACK`
5. Use `write_output "KEY" "$value"` to set outputs (writes to both `$GITHUB_OUTPUT` and `$GITHUB_ENV`)
6. Add the case entry in `entrypoint.sh`
7. Add the action name to the `action` input's description list in `action.yml`
8. Add any new inputs/outputs to `action.yml`
9. Update the README.md input/output tables and add a usage example

### Shell Script Rules

- Always use `set -e` (never `set -x` — it leaks secrets into logs)
- Always quote variable expansions: `"$INPUT_APP"` not `$INPUT_APP`
- Use `::error::` prefix for error messages (GitHub Actions annotation)
- Use `::add-mask::` before exposing any secret values
- Source `lib/common.sh` for shared helpers
- Output names are UPPERCASE (e.g., `RELEASE`, `DESIRED`, `PARAM_VALUE`)

### Shared Functions (lib/common.sh)

| Function | Purpose |
|----------|---------|
| `set_rack` | Exports `CONVOX_RACK` from `INPUT_RACK` (required) |
| `set_host` | Exports `CONVOX_HOST` from `INPUT_HOST` or default |
| `set_password` | Exports `CONVOX_PASSWORD` from `INPUT_PASSWORD` |
| `require_input NAME VALUE` | Fails with error if value is empty |
| `write_output KEY VALUE` | Writes to both `$GITHUB_OUTPUT` and `$GITHUB_ENV` |
| `build_cache_flag` | Returns `--no-cache` if `INPUT_CACHED=false` |
| `build_external_flag` | Returns `--external` if `INPUT_EXTERNAL=true` |
| `build_manifest_flag` | Returns `-m <path>` if `INPUT_MANIFEST` is set |
| `resolve_release [required]` | Sets `RELEASE` from `INPUT_RELEASE` or env |

### Input → Action Matrix

| Action | Required Inputs | Optional Inputs | Outputs |
|--------|----------------|-----------------|---------|
| `login` | `password` | `host` | — |
| `login-user` | `token` | `host` | — |
| `build` | `rack`, `app` | `description`, `cached`, `external`, `manifest` | `RELEASE` |
| `build-migrate` | `rack`, `app`, `destinationApp`, `destinationRack` | — | `RELEASE` |
| `deploy` | `rack`, `app` | `password`, `host`, `description`, `cached`, `external`, `manifest` | — |
| `create` | `rack`, `app` | — | — |
| `destroy` | `rack`, `app` | — | — |
| `promote` | `rack`, `app`, `release` | — | — |
| `rollback` | `rack`, `app`, `release` | — | — |
| `run` | `rack`, `app`, `service`, `command` | `release` | — |
| `scale` | `rack`, `app`, `service`, `count` | — | — |
| `get-scale` | `rack`, `app`, `service` | — | `DESIRED`, `RUNNING`, `CPU`, `MEMORY`, `SCALING_EVENT`, `RUNNING_PROCESSES`, `PENDING_PROCESSES`, `UNHEALTHY_PROCESSES` |
| `env-set` | `rack`, `app`, `env` | — | — |
| `find-build` | `rack`, `app`, `description` | — | `BUILD` |
| `find-release` | `rack`, `app`, `description` | — | `RELEASE` |
| `get-rack-param` | `rack`, `paramName` | — | `PARAM_VALUE` |
| `rack-param` | `rack`, `paramName`, `paramValue` | — | — |

### Versioning and releasing

Merged PRs release automatically when labelled `release` (a minor version bump), and a daily workflow auto-updates the Convox CLI version (a patch bump). For a manual release: `VERSION=v3.x.x make release`, which writes the `VERSION` file, commits, creates a signed git tag, pushes, and re-points the `v3` major alias.

### Testing

Follow TDD (red/green/refactor): always write failing tests first, then implement the code to make them pass, then refactor if needed.

Run ShellCheck locally: `shellcheck -x entrypoint*.sh lib/common.sh tests/helpers.bash`
Run tests: `bats tests/`

### Security

- Never use `set -x` — it echoes commands containing secrets
- Always mask secrets with `::add-mask::` before writing to environment
- Quote all variables to prevent injection
