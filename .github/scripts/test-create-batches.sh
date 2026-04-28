#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_success_case() {
  local name="$1"
  local hosts="$2"
  local batch_size="$3"
  local expected_total="$4"
  local expected_batches="$5"
  local output_file

  output_file="$(mktemp)"
  DEPLOYMENT_HOSTS="$hosts" \
    BATCH_SIZE="$batch_size" \
    GITHUB_OUTPUT="$output_file" \
    bash "$script_dir/create-batches.sh" >/dev/null

  grep -Fx "total_hosts=$expected_total" "$output_file" >/dev/null
  grep -Fx "total_batches=$expected_batches" "$output_file" >/dev/null
  rm -f "$output_file"
  echo "ok - $name"
}

run_failure_case() {
  local name="$1"
  local hosts="$2"
  local batch_size="$3"
  local output_file

  output_file="$(mktemp)"
  if DEPLOYMENT_HOSTS="$hosts" \
      BATCH_SIZE="$batch_size" \
      GITHUB_OUTPUT="$output_file" \
      bash "$script_dir/create-batches.sh" >/dev/null 2>&1; then
    echo "not ok - $name" >&2
    rm -f "$output_file"
    exit 1
  fi

  rm -f "$output_file"
  echo "ok - $name"
}

run_success_case \
  "trims whitespace and batches hosts" \
  $' 172.31.1.5 \n\nhost-2.example.com\nhost3' \
  "2" \
  "3" \
  "2"

run_success_case \
  "accepts maximum batch size" \
  $'h1\nh2\nh3\nh4\nh5' \
  "256" \
  "5" \
  "1"

run_failure_case "rejects empty host list" "" "256"
run_failure_case "rejects invalid host" $'good\nbad host' "256"
run_failure_case "rejects duplicate host" $'host1\nhost1' "256"
run_failure_case "rejects zero batch size" "host1" "0"
run_failure_case "rejects nonnumeric batch size" "host1" "abc"
run_failure_case "rejects oversized batch size" "host1" "257"
