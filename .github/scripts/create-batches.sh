#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/scripts/lib.sh
source "$script_dir/lib.sh"

require_tool jq
require_env GITHUB_OUTPUT

batch_size_input="${BATCH_SIZE:-256}"
if [[ ! "$batch_size_input" =~ ^[0-9]+$ ]]; then
  echo "batch_size must be numeric: $batch_size_input" >&2
  exit 1
fi

batch_size=$((10#$batch_size_input))
if ((batch_size < 1 || batch_size > 256)); then
  echo "batch_size must be between 1 and 256: $batch_size" >&2
  exit 1
fi

hosts_json="$(
  printf '%s\n' "${DEPLOYMENT_HOSTS:-}" |
    tr -d '\r' |
    jq -Rsc '
      split("\n")
      | map(gsub("^\\s+|\\s+$"; ""))
      | map(select(length > 0))
    '
)"

total_hosts="$(jq 'length' <<<"$hosts_json")"
if ((total_hosts == 0)); then
  echo "DEPLOYMENT_HOSTS must contain at least one host" >&2
  exit 1
fi

invalid_hosts="$(
  jq -r '
    .[]
    | select(
        (test("^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$") | not)
        or contains("..")
      )
  ' <<<"$hosts_json"
)"

if [[ -n "$invalid_hosts" ]]; then
  echo "DEPLOYMENT_HOSTS contains invalid host values:" >&2
  printf '%s\n' "$invalid_hosts" >&2
  exit 1
fi

duplicate_hosts="$(
  jq -r '
    group_by(.)
    | map(select(length > 1) | .[0])
    | .[]
  ' <<<"$(jq -c 'sort' <<<"$hosts_json")"
)"

if [[ -n "$duplicate_hosts" ]]; then
  echo "DEPLOYMENT_HOSTS contains duplicate hosts:" >&2
  printf '%s\n' "$duplicate_hosts" >&2
  exit 1
fi

total_batches=$(((total_hosts + batch_size - 1) / batch_size))
batches="$(
  jq -c --argjson batch_size "$batch_size" '
    [range(0; length; $batch_size) as $start
      | .[$start:($start + $batch_size)]]
  ' <<<"$hosts_json"
)"

{
  echo "batches=$batches"
  echo "total_hosts=$total_hosts"
  echo "total_batches=$total_batches"
} >> "$GITHUB_OUTPUT"

echo "Prepared $total_hosts hosts across $total_batches batches"
