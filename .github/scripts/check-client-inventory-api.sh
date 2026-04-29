#!/usr/bin/env bash
set -uo pipefail

OPENAPI_FILE="${OPENAPI_FILE:-openapi.json}"
CONFIG_FILE="${CONFIG_FILE:-config.ini}"
CLIENT_INVENTORY_SAMPLE_SIZE="${CLIENT_INVENTORY_SAMPLE_SIZE:-1}"
API_CHECK_DRY_RUN="${API_CHECK_DRY_RUN:-false}"
API_CHECK_WARN_ONLY="${API_CHECK_WARN_ONLY:-false}"
API_CHECK_TIMEOUT="${API_CHECK_TIMEOUT:-20}"
API_CHECK_CONNECT_TIMEOUT="${API_CHECK_CONNECT_TIMEOUT:-10}"

EXPECTED_OPERATIONS=(
  listClients
  getClient
  getClientConfig
  batchGetConfigs
)

fail() {
  echo "ERROR: $*" >&2
  return 1
}

warn() {
  echo "WARNING: $*" >&2
}

is_true() {
  [[ "${1,,}" == "true" || "$1" == "1" || "${1,,}" == "yes" ]]
}

require_tool() {
  local tool_name="$1"

  command -v "$tool_name" >/dev/null 2>&1 ||
    fail "Missing required tool: $tool_name"
}

validate_sample_size() {
  [[ "$CLIENT_INVENTORY_SAMPLE_SIZE" =~ ^[0-9]+$ ]] ||
    fail "CLIENT_INVENTORY_SAMPLE_SIZE must be numeric"

  if ((CLIENT_INVENTORY_SAMPLE_SIZE < 1 || CLIENT_INVENTORY_SAMPLE_SIZE > 100)); then
    fail "CLIENT_INVENTORY_SAMPLE_SIZE must be between 1 and 100"
  fi
}

validate_openapi() {
  [[ -f "$OPENAPI_FILE" ]] || fail "OpenAPI file not found: $OPENAPI_FILE"
  jq empty "$OPENAPI_FILE" || return 1

  local operation
  for operation in "${EXPECTED_OPERATIONS[@]}"; do
    jq -e --arg operation "$operation" '
      [
        .. | objects | select(has("operationId")) | .operationId
      ] | index($operation)
    ' "$OPENAPI_FILE" >/dev/null ||
      fail "OpenAPI operation is missing: $operation" ||
      return 1
  done

  jq -e '
    .paths["/clients"].get.operationId == "listClients" and
    .paths["/clients/{id}"].get.operationId == "getClient" and
    .paths["/clients/{id}/config"].get.operationId == "getClientConfig" and
    .paths["/clients/configs:batch"].post.operationId == "batchGetConfigs"
  ' "$OPENAPI_FILE" >/dev/null ||
    fail "OpenAPI paths do not match expected Client Inventory operations"
}

derive_base_url() {
  local base_url="${CLIENT_INVENTORY_API_BASE_URL:-}"
  local controller_url

  if [[ -z "$base_url" ]]; then
    [[ -f "$CONFIG_FILE" ]] || fail "Config file not found: $CONFIG_FILE"
    controller_url="$(
      awk -F= '
        /^[[:space:]]*ControllerURL[[:space:]]*=/ {
          gsub(/[[:space:]]/, "", $2)
          print $2
          exit
        }
      ' "$CONFIG_FILE"
    )"

    [[ -n "$controller_url" ]] ||
      fail "ControllerURL was not found in $CONFIG_FILE" ||
      return 1

    base_url="https://${controller_url}/fm-service/v1"
  fi

  base_url="${base_url%/}"
  [[ "$base_url" =~ ^https?://[^/[:space:]]+/.+ ]] ||
    fail "CLIENT_INVENTORY_API_BASE_URL must include scheme, host, and path"

  printf '%s\n' "$base_url"
}

urlencode() {
  jq -nr --arg value "$1" '$value | @uri'
}

request_json() {
  local method="$1"
  local url="$2"
  local response_file="$3"
  local body_file="${4:-}"
  local status
  local curl_status
  local curl_args=(
    --silent
    --show-error
    --connect-timeout "$API_CHECK_CONNECT_TIMEOUT"
    --max-time "$API_CHECK_TIMEOUT"
    --request "$method"
    --header "Accept: application/json"
    --header "X-SF-Token: ${CLIENT_INVENTORY_API_TOKEN}"
    --output "$response_file"
    --write-out "%{http_code}"
  )

  if [[ -n "$body_file" ]]; then
    curl_args+=(
      --header "Content-Type: application/json"
      --data-binary "@${body_file}"
    )
  fi

  status="$(curl "${curl_args[@]}" "$url")"
  curl_status=$?

  if ((curl_status != 0)); then
    fail "curl failed for $method $url"
    return 1
  fi

  if [[ "$status" != "200" ]]; then
    echo "Response body:" >&2
    sed -n '1,40p' "$response_file" >&2
    fail "$method $url returned HTTP $status, expected 200"
    return 1
  fi

  jq empty "$response_file" >/dev/null 2>&1 ||
    fail "$method $url did not return valid JSON"
}

run_live_checks() {
  local base_url="$1"
  local tmp_dir="$2"
  local list_response="$tmp_dir/list.json"
  local client_response="$tmp_dir/client.json"
  local config_response="$tmp_dir/config.json"
  local batch_body="$tmp_dir/batch-request.json"
  local batch_response="$tmp_dir/batch-response.json"
  local encoded_client_id
  local first_client_id
  local client_ids_json

  request_json \
    GET \
    "${base_url}/clients?limit=${CLIENT_INVENTORY_SAMPLE_SIZE}&include_health=false" \
    "$list_response" ||
    return 1

  jq -e '
    type == "object" and
    (.clients | type == "array") and
    (.pagination | type == "object")
  ' "$list_response" >/dev/null ||
    fail "GET /clients response did not match expected list shape" ||
    return 1

  client_ids_json="$(
    jq -c --argjson limit "$CLIENT_INVENTORY_SAMPLE_SIZE" '
      [.clients[:$limit][]?.instance_uid | select(type == "string" and length > 0)]
    ' "$list_response"
  )"

  first_client_id="$(jq -r '.[0] // empty' <<<"$client_ids_json")"
  if [[ -z "$first_client_id" ]]; then
    warn "GET /clients returned no clients; skipping ID-based operations"
    return 0
  fi

  encoded_client_id="$(urlencode "$first_client_id")"

  request_json GET "${base_url}/clients/${encoded_client_id}" "$client_response" ||
    return 1
  jq -e --arg id "$first_client_id" '
    type == "object" and .instance_uid == $id
  ' "$client_response" >/dev/null ||
    fail "GET /clients/{id} response did not match requested client ID" ||
    return 1

  request_json \
    GET \
    "${base_url}/clients/${encoded_client_id}/config?stringify=true" \
    "$config_response" ||
    return 1
  jq -e 'type == "object"' "$config_response" >/dev/null ||
    fail "GET /clients/{id}/config response was not an object" ||
    return 1

  jq -n --argjson clientIds "$client_ids_json" \
    '{clientIds: $clientIds, stringify: true}' > "$batch_body"

  request_json POST "${base_url}/clients/configs:batch" "$batch_response" "$batch_body" ||
    return 1
  jq -e 'type == "object"' "$batch_response" >/dev/null ||
    fail "POST /clients/configs:batch response was not an object"
}

run_check() {
  local base_url
  local tmp_dir

  require_tool awk || return 1
  require_tool curl || return 1
  require_tool jq || return 1
  validate_sample_size || return 1
  validate_openapi || return 1

  base_url="$(derive_base_url)" || return 1
  echo "Client Inventory API base URL: $base_url"
  echo "OpenAPI file: $OPENAPI_FILE"
  echo "Sample size: $CLIENT_INVENTORY_SAMPLE_SIZE"

  if is_true "$API_CHECK_DRY_RUN"; then
    if [[ -n "${CLIENT_INVENTORY_API_TOKEN:-}" ]]; then
      echo "Token: configured"
    else
      echo "Token: missing"
    fi
    echo "Dry run complete; live API requests were not sent"
    return 0
  fi

  [[ -n "${CLIENT_INVENTORY_API_TOKEN:-}" ]] ||
    fail "CLIENT_INVENTORY_API_TOKEN is required for live API checks" ||
    return 1

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  run_live_checks "$base_url" "$tmp_dir" || return 1
  echo "Client Inventory API check passed"
}

run_check
status=$?

if ((status == 0)); then
  exit 0
fi

if is_true "$API_CHECK_WARN_ONLY"; then
  echo "::warning::Client Inventory API check failed; continuing because warn-only mode is enabled"
  exit 0
fi

exit "$status"
