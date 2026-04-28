#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
script="$script_dir/check-client-inventory-api.sh"

run_success_case() {
  local name="$1"
  shift

  if "$@" >/tmp/client_inventory_test.out 2>&1; then
    echo "ok - $name"
  else
    echo "not ok - $name" >&2
    cat /tmp/client_inventory_test.out >&2
    exit 1
  fi
}

run_failure_case() {
  local name="$1"
  shift

  if "$@" >/tmp/client_inventory_test.out 2>&1; then
    echo "not ok - $name" >&2
    cat /tmp/client_inventory_test.out >&2
    exit 1
  fi

  echo "ok - $name"
}

run_success_case \
  "derives base URL from config.ini" \
  env \
    API_CHECK_DRY_RUN=true \
    CLIENT_INVENTORY_API_TOKEN=test-token \
    bash "$script"
grep -F "https://fso-tme.saas.appdynamics.com/fm-service/v1" \
  /tmp/client_inventory_test.out >/dev/null

run_success_case \
  "accepts explicit base URL override" \
  env \
    API_CHECK_DRY_RUN=true \
    CLIENT_INVENTORY_API_BASE_URL=https://example.test/fm-service/v1/ \
    CLIENT_INVENTORY_API_TOKEN=test-token \
    bash "$script"
grep -F "https://example.test/fm-service/v1" \
  /tmp/client_inventory_test.out >/dev/null

run_success_case \
  "dry-run reports missing token without failing" \
  env \
    API_CHECK_DRY_RUN=true \
    bash "$script"
grep -F "Token: missing" /tmp/client_inventory_test.out >/dev/null

run_success_case \
  "warn-only mode tolerates missing token" \
  env \
    API_CHECK_WARN_ONLY=true \
    bash "$script"
grep -F "warn-only mode is enabled" /tmp/client_inventory_test.out >/dev/null

bad_openapi="$(mktemp)"
trap 'rm -f "$bad_openapi" /tmp/client_inventory_test.out' EXIT
jq 'del(.paths["/clients"].get.operationId)' \
  "$repo_root/openapi.json" > "$bad_openapi"

run_failure_case \
  "rejects missing OpenAPI operation" \
  env \
    API_CHECK_DRY_RUN=true \
    OPENAPI_FILE="$bad_openapi" \
    CLIENT_INVENTORY_API_TOKEN=test-token \
    bash "$script"
