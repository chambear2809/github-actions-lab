#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/scripts/lib.sh
source "$script_dir/lib.sh"

require_tool awk
require_tool jq
require_tool scp
require_tool sha256sum
require_tool ssh
require_tool ssh-keyscan
require_env APPD_ACCOUNT_ACCESS_KEY

validate_batch_hosts_json
initialize_remote_identity

shopt -s nullglob
agent_zips=(appdsmartagent_64_linux_*.zip)
shopt -u nullglob

if (( ${#agent_zips[@]} != 1 )); then
  echo "Expected exactly one appdsmartagent_64_linux_*.zip file" >&2
  printf 'Found: %s\n' "${agent_zips[@]:-none}" >&2
  exit 1
fi

agent_zip="${agent_zips[0]}"
agent_zip_basename="$(basename "$agent_zip")"
checksum_file=".github/checksums/${agent_zip_basename}.sha256"

if [[ ! -f "$checksum_file" ]]; then
  echo "Missing checksum file: $checksum_file" >&2
  exit 1
fi

sha256sum --check "$checksum_file"

tmp_dir="$(mktemp -d)"
key_file="$tmp_dir/id_rsa"
config_file="$tmp_dir/config.ini"
fail_file="$tmp_dir/failed_hosts"
touch "$fail_file"
trap 'rm -rf "$tmp_dir"' EXIT

awk '
  {
    while ((placeholder = index($0, "{{ACCOUNT_ACCESS_KEY}}")) > 0) {
      $0 = substr($0, 1, placeholder - 1) \
        ENVIRON["APPD_ACCOUNT_ACCESS_KEY"] \
        substr($0, placeholder + 22)
    }
    print
  }
' config.ini > "$config_file"

write_ssh_key "$key_file"

batch_size="$(jq 'length' <<<"$BATCH_HOSTS")"
echo "Deploying $agent_zip_basename to batch of $batch_size hosts"

remote_script="$(
  cat <<EOF
sudo apt-get update -qq
sudo apt-get install -y unzip
sudo rm -rf /opt/appdynamics/appdsmartagent
sudo mkdir -p /opt/appdynamics/appdsmartagent
sudo unzip -oq "/tmp/$agent_zip_basename" -d /opt/appdynamics/appdsmartagent
sudo cp /tmp/config.ini /opt/appdynamics/appdsmartagent/config.ini
sudo rm -f "/tmp/$agent_zip_basename" /tmp/config.ini
sudo chown -R "\$TARGET_OWNER:\$TARGET_GROUP" /opt/appdynamics/appdsmartagent

cd /opt/appdynamics/appdsmartagent
if [[ -n "\$SMARTAGENT_USER" && -n "\$SMARTAGENT_GROUP" ]]; then
  sudo ./smartagentctl start \\
    --enable-auto-attach \\
    --service \\
    --user "\$SMARTAGENT_USER" \\
    --group "\$SMARTAGENT_GROUP"
else
  sudo ./smartagentctl start --enable-auto-attach --service
fi
sudo systemctl daemon-reload
sudo systemctl is-active --quiet smartagent.service
status_output="\$(sudo ./smartagentctl status)"
echo "\$status_output"
[[ "\$status_output" == *Running* ]]
EOF
)"

while IFS= read -r host; do
  (
    known_hosts_file="$(mktemp "$tmp_dir/known_hosts.XXXXXX")"
    echo "Starting deployment to $host"

    if ! scan_host_key "$host" "$known_hosts_file"; then
      echo "$host" >> "$fail_file"
      exit 0
    fi

    if ! copy_to_remote_tmp \
        "$host" \
        "$key_file" \
        "$known_hosts_file" \
        "$agent_zip" \
        "$config_file"; then
      echo "Failed to copy deployment artifacts to $host" >&2
      echo "$host" >> "$fail_file"
      exit 0
    fi

    if run_remote_script "$host" "$key_file" "$known_hosts_file" "$remote_script"; then
      echo "Completed deployment to $host"
    else
      echo "Failed deployment to $host" >&2
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

echo "Batch deployment complete"
