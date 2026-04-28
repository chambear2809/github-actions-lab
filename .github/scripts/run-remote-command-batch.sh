#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/scripts/lib.sh
source "$script_dir/lib.sh"

require_tool jq
require_tool ssh
require_tool ssh-keyscan
require_env REMOTE_COMMAND

validate_batch_hosts_json
initialize_remote_identity

operation_label="${OPERATION_LABEL:-Run remote command}"
batch_size="$(jq 'length' <<<"$BATCH_HOSTS")"

tmp_dir="$(mktemp -d)"
key_file="$tmp_dir/id_rsa"
fail_file="$tmp_dir/failed_hosts"
touch "$fail_file"
trap 'rm -rf "$tmp_dir"' EXIT

write_ssh_key "$key_file"

echo "$operation_label on batch of $batch_size hosts"

while IFS= read -r host; do
  (
    known_hosts_file="$(mktemp "$tmp_dir/known_hosts.XXXXXX")"
    echo "Starting $operation_label on $host"

    if ! scan_host_key "$host" "$known_hosts_file"; then
      echo "$host" >> "$fail_file"
      exit 0
    fi

    if run_remote_script "$host" "$key_file" "$known_hosts_file" "$REMOTE_COMMAND"; then
      echo "Completed $operation_label on $host"
    else
      echo "Failed $operation_label on $host" >&2
      echo "$host" >> "$fail_file"
    fi
  ) &
done < <(jq -r '.[]' <<<"$BATCH_HOSTS")

wait || true

if [[ -s "$fail_file" ]]; then
  echo "Some hosts failed:" >&2
  sort -u "$fail_file" >&2
  exit 1
fi

echo "Batch complete"
