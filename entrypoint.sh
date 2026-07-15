#!/bin/sh
set -e

# Resolve script directory — supports both composite actions ($GITHUB_ACTION_PATH)
# and local execution (dirname of this script).
ACTION_DIR="${GITHUB_ACTION_PATH:-$(cd "$(dirname "$0")" && pwd)}"

# Make sure all environment variables are exported
set -a

# Get the value of the environment variable
value=$INPUT_ACTION

# Perform switch case based on the value
case "$value" in
  "build")
    "$ACTION_DIR/entrypoint-build.sh"
    ;;
  "build-migrate")
    "$ACTION_DIR/entrypoint-build-migrate.sh"
    ;;
  "create")
    "$ACTION_DIR/entrypoint-create.sh"
    ;;
  "deploy")
    "$ACTION_DIR/entrypoint-deploy.sh"
    ;;
  "destroy")
    "$ACTION_DIR/entrypoint-destroy.sh"
    ;;
  "app-param")
    "$ACTION_DIR/entrypoint-app-param.sh"
    ;;
  "env-copy")
    "$ACTION_DIR/entrypoint-env-copy.sh"
    ;;
  "env-set")
    "$ACTION_DIR/entrypoint-env-set.sh"
    ;;
  "find-build")
    "$ACTION_DIR/entrypoint-find-build.sh"
    ;;
  "find-release")
    "$ACTION_DIR/entrypoint-find-release.sh"
    ;;
  "get-scale")
    "$ACTION_DIR/entrypoint-get-scale.sh"
    ;;
  "get-rack-param")
    "$ACTION_DIR/entrypoint-get-rack-param.sh"
    ;;
  "login")
    "$ACTION_DIR/entrypoint-login.sh"
    ;;
  "login-user")
    "$ACTION_DIR/entrypoint-login-user.sh"
    ;;
  "promote")
    "$ACTION_DIR/entrypoint-promote.sh"
    ;;
  "rack-param")
    "$ACTION_DIR/entrypoint-rack-param.sh"
    ;;
  "rollback")
    "$ACTION_DIR/entrypoint-rollback.sh"
    ;;
  "run")
    "$ACTION_DIR/entrypoint-run.sh"
    ;;
  "scale")
    "$ACTION_DIR/entrypoint-scale.sh"
    ;;
  *)
    echo "Invalid action chosen: '$value'"
    exit 1
    ;;
esac
