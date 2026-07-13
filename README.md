# action-convox-multi-slim

Multiple Convox CLI commands in one slim Docker-based GitHub Action. Instead of using separate actions for each Convox operation, this single action supports 17 commands through the `action` input, reducing workflow boilerplate.

## Supported Actions

`login` · `login-user` · `build` · `build-migrate` · `deploy` · `create` · `destroy` · `promote` · `rollback` · `run` · `scale` · `get-scale` · `env-set` · `find-build` · `find-release` · `get-rack-param` · `rack-param`

## Quick Start

```yaml
# Step 1: Login to Convox (required before any other action)
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: login
    password: ${{ secrets.CONVOX_PASSWORD }}

# Step 2: Build your app
- uses: beastawakens/action-convox-multi-slim@v3
  id: build
  with:
    action: build
    rack: my-rack
    app: my-app
    description: "Build ${{ github.sha }}"

# Step 3: Promote the release
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: promote
    rack: my-rack
    app: my-app
    release: ${{ steps.build.outputs.RELEASE }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `action` | Convox command to run (see supported actions above) | Yes | — |
| `password` | Convox deploy key | For `login` | — |
| `host` | Convox Console host address | No | `console.convox.com` |
| `token` | Convox Console token | For `login-user` | — |
| `rack` | Convox Rack name | For most actions | — |
| `app` | Convox app name | For most actions | — |
| `destinationApp` | Destination app name | For `build-migrate` | — |
| `destinationRack` | Destination rack name | For `build-migrate` | — |
| `description` | Build description | No | — |
| `cached` | Use Docker cache during build | No | `true` |
| `errorOnZeroScale` | Fail `get-scale` when no running processes are found | No | `false` |
| `external` | Build locally and push to rack registry (bypasses LB upload) | No | `false` |
| `manifest` | Custom path for convox.yml | No | — |
| `paramName` | Rack parameter name | For `get-rack-param`, `rack-param` | — |
| `paramValue` | Rack parameter value | For `rack-param` | — |
| `release` | Release ID (auto-detected from prior build step if omitted) | For `promote`, `rollback` | — |
| `service` | Service name | For `run`, `scale`, `get-scale` | — |
| `command` | Command to run | For `run` | — |
| `count` | Instance count to scale to | For `scale` | — |
| `env` | Env vars as `key1=value1 key2=value2` | For `env-set` | — |

## Outputs

| Output | Description | Set by |
|--------|-------------|--------|
| `RELEASE` | Release ID of the created build | `build`, `build-migrate`, `find-release` |
| `BUILD` | Build ID matching the description | `find-build` |
| `DESIRED` | Count of desired instances | `get-scale` |
| `RUNNING` | Count of running instances | `get-scale` |
| `CPU` | CPU scale value | `get-scale` |
| `MEMORY` | Memory scale value | `get-scale` |
| `SCALING_EVENT` | `true` if desired ≠ running | `get-scale` |
| `RUNNING_PROCESSES` | Count of running processes | `get-scale` |
| `PENDING_PROCESSES` | Count of pending processes | `get-scale` |
| `UNHEALTHY_PROCESSES` | Count of unhealthy processes | `get-scale` |
| `PARAM_VALUE` | Rack parameter value | `get-rack-param` |

## Action-by-Action Usage

### login

Stores Convox credentials for subsequent steps. Must be called before any other action.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: login
    password: ${{ secrets.CONVOX_PASSWORD }}
    host: console.convox.com  # optional
```

### login-user

Authenticates an interactive user via token.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: login-user
    token: ${{ secrets.CONVOX_TOKEN }}
```

### build

Builds the app and returns the release ID.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  id: build
  with:
    action: build
    rack: my-rack
    app: my-app
    description: "Build ${{ github.sha }}"
    cached: true          # optional, default true
    external: false       # optional, default false
    manifest: convox.yml  # optional
```

### deploy

Builds and deploys in a single operation (waits for completion).

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: deploy
    rack: my-rack
    app: my-app
    description: "Deploy ${{ github.sha }}"
    external: false       # optional, default false
```

### build-migrate

Exports a build from one app/rack and imports it to another.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: build-migrate
    rack: source-rack
    app: source-app
    destinationRack: dest-rack
    destinationApp: dest-app
```

### create

Creates a new Convox app.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: create
    rack: my-rack
    app: my-new-app
```

### destroy

Deletes a Convox app.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: destroy
    rack: my-rack
    app: my-app
```

### promote

Promotes a release to active.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: promote
    rack: my-rack
    app: my-app
    release: RABCDEF1234  # or auto-detected from prior build step
```

### rollback

Rolls back to a previous release.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: rollback
    rack: my-rack
    app: my-app
    release: RABCDEF1234
```

### run

Runs a one-off command against a service.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: run
    rack: my-rack
    app: my-app
    service: web
    command: "rails db:migrate"
    release: RABCDEF1234  # optional
```

### scale

Scales a service to a specific instance count.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: scale
    rack: my-rack
    app: my-app
    service: web
    count: 3
```

### get-scale

Retrieves current scale information and process status.

By default, `get-scale` reports process counts even when there are zero running processes. Set `errorOnZeroScale: true` to make the step fail when `RUNNING_PROCESSES=0`.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  id: scale-info
  with:
    action: get-scale
    rack: my-rack
    app: my-app
    service: web
    errorOnZeroScale: true  # optional, default false

- run: |
    echo "Desired: ${{ steps.scale-info.outputs.DESIRED }}"
    echo "Running: ${{ steps.scale-info.outputs.RUNNING }}"
    echo "Scaling: ${{ steps.scale-info.outputs.SCALING_EVENT }}"
```

### env-set

Sets environment variables on an app.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: env-set
    rack: my-rack
    app: my-app
    env: "KEY1=value1 KEY2=value2"
```

### find-build

Finds the first build matching a description.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  id: found
  with:
    action: find-build
    rack: my-rack
    app: my-app
    description: "target-description"
```

### find-release

Finds the first release matching a description.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  id: found
  with:
    action: find-release
    rack: my-rack
    app: my-app
    description: "target-description"
```

### get-rack-param

Retrieves a rack parameter value.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  id: param
  with:
    action: get-rack-param
    rack: my-rack
    paramName: my_param

- run: echo "Value: ${{ steps.param.outputs.PARAM_VALUE }}"
```

### rack-param

Sets a rack parameter value.

```yaml
- uses: beastawakens/action-convox-multi-slim@v3
  with:
    action: rack-param
    rack: my-rack
    paramName: my_param
    paramValue: new_value
```

## Prerequisites

- A Convox account with a deployed rack
- A Convox deploy key (`password`) or user token (`token`)
- The `login` or `login-user` action must be called before any other action in your workflow

## Releasing a New Version

```sh
export VERSION=v1.x.x
make release
```

Releases automatically re-point the `v3` major tag, so pin `@v3` for automatic updates or an exact tag such as `@v3.0.10` for immutability.

Merged pull requests only release automatically when labelled `release`; unlabelled merges don't bump the version.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development details.

## License

[Mozilla Public License 2.0](LICENSE)

