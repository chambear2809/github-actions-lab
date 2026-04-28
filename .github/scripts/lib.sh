#!/usr/bin/env bash

require_tool() {
  local tool_name="$1"

  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "Missing required tool: $tool_name" >&2
    exit 1
  fi
}

require_env() {
  local env_name="$1"

  if [[ -z "${!env_name:-}" ]]; then
    echo "Missing required environment variable: $env_name" >&2
    exit 1
  fi
}

validate_host() {
  local host="$1"

  if [[ ! "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
    echo "Invalid host value: $host" >&2
    exit 1
  fi

  if [[ "$host" == *..* ]]; then
    echo "Invalid host value: $host" >&2
    exit 1
  fi
}

validate_account_name() {
  local name="$1"
  local value="$2"

  if [[ -n "$value" && ! "$value" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]]; then
    echo "Invalid $name value: $value" >&2
    exit 1
  fi
}

validate_group_name() {
  local name="$1"
  local value="$2"

  if [[ -n "$value" && ! "$value" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]]; then
    echo "Invalid $name value: $value" >&2
    exit 1
  fi
}

validate_batch_hosts_json() {
  require_env BATCH_HOSTS
  require_tool jq

  jq -e '
    type == "array"
    and length > 0
    and all(.[]; type == "string" and length > 0)
  ' <<<"$BATCH_HOSTS" >/dev/null

  while IFS= read -r host; do
    validate_host "$host"
  done < <(jq -r '.[]' <<<"$BATCH_HOSTS")
}

write_ssh_key() {
  local key_file="$1"

  require_env SSH_PRIVATE_KEY
  printf '%s\n' "$SSH_PRIVATE_KEY" > "$key_file"
  chmod 600 "$key_file"
}

scan_host_key() {
  local host="$1"
  local known_hosts_file="$2"
  local timeout="${SSH_KEYSCAN_TIMEOUT:-10}"

  if ! ssh-keyscan -T "$timeout" "$host" > "$known_hosts_file" 2>/dev/null; then
    echo "Failed to collect SSH host key for $host" >&2
    return 1
  fi

  if [[ ! -s "$known_hosts_file" ]]; then
    echo "No SSH host key returned for $host" >&2
    return 1
  fi
}

remote_launcher() {
  printf \
    'SSH_USER=%s SMARTAGENT_USER=%s SMARTAGENT_GROUP=%s TARGET_OWNER=%s TARGET_GROUP=%s bash -seuo pipefail' \
    "$SSH_USER" \
    "${SMARTAGENT_USER:-}" \
    "${SMARTAGENT_GROUP:-}" \
    "$TARGET_OWNER" \
    "$TARGET_GROUP"
}

run_remote_script() {
  local host="$1"
  local key_file="$2"
  local known_hosts_file="$3"
  local remote_script="$4"
  local connect_timeout="${SSH_CONNECT_TIMEOUT:-30}"

  ssh \
    -i "$key_file" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$known_hosts_file" \
    -o ConnectTimeout="$connect_timeout" \
    "${SSH_USER}@${host}" \
    "$(remote_launcher)" \
    <<<"$remote_script"
}

copy_to_remote_tmp() {
  local host="$1"
  local key_file="$2"
  local known_hosts_file="$3"
  local connect_timeout="${SSH_CONNECT_TIMEOUT:-30}"
  shift 3

  scp \
    -i "$key_file" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$known_hosts_file" \
    -o ConnectTimeout="$connect_timeout" \
    "$@" \
    "${SSH_USER}@${host}:/tmp/"
}

initialize_remote_identity() {
  SSH_USER="${SSH_USER:-ubuntu}"
  SMARTAGENT_USER="${SMARTAGENT_USER:-}"
  SMARTAGENT_GROUP="${SMARTAGENT_GROUP:-}"

  validate_account_name SSH_USER "$SSH_USER"
  validate_account_name SMARTAGENT_USER "$SMARTAGENT_USER"
  validate_group_name SMARTAGENT_GROUP "$SMARTAGENT_GROUP"

  if [[ -n "$SMARTAGENT_USER" && -z "$SMARTAGENT_GROUP" ]]; then
    echo "SMARTAGENT_GROUP is required when SMARTAGENT_USER is set" >&2
    exit 1
  fi

  if [[ -z "$SMARTAGENT_USER" && -n "$SMARTAGENT_GROUP" ]]; then
    echo "SMARTAGENT_USER is required when SMARTAGENT_GROUP is set" >&2
    exit 1
  fi

  TARGET_OWNER="${SMARTAGENT_USER:-$SSH_USER}"
  TARGET_GROUP="${SMARTAGENT_GROUP:-$TARGET_OWNER}"
}
