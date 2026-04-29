#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/scripts/lib.sh
source "$script_dir/lib.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

write_output() {
  local name="$1"
  local content="$2"
  local output_file="$tmp_dir/$name"

  printf '%s\n' "$content" > "$output_file"
  printf '%s\n' "$output_file"
}

run_reports_error_case() {
  local name="$1"
  local content="$2"
  local output_file

  output_file="$(write_output "$name" "$content")"
  if ! remote_output_reports_error "$output_file"; then
    echo "not ok - $name" >&2
    exit 1
  fi

  echo "ok - $name"
}

run_no_error_case() {
  local name="$1"
  local content="$2"
  local output_file

  output_file="$(write_output "$name" "$content")"
  if remote_output_reports_error "$output_file"; then
    echo "not ok - $name" >&2
    exit 1
  fi

  echo "ok - $name"
}

run_reports_error_case "detects structured smartagent error" '{"error": true}'
run_reports_error_case \
  "detects smartagent error inside mixed output" \
  $'starting\n{\n  "error": true,\n  "logs": "failed"\n}'
run_no_error_case "accepts structured smartagent success" '{"error": false}'
run_no_error_case "ignores unrelated text" "error: true but not JSON"
