# AppDynamics Smart Agent Deployment Guide

## Overview

This repository deploys and manages AppDynamics Smart Agent on Ubuntu EC2 hosts
from GitHub Actions running on a self-hosted runner in the same AWS VPC.

All lifecycle workflows are manual, batch hosts from `DEPLOYMENT_HOSTS`, and
process one batch at a time while running SSH work in parallel inside each
batch.

## Required Configuration

### GitHub Secrets

Set these in **Settings -> Secrets and variables -> Actions -> Secrets**:

- `SSH_PRIVATE_KEY`: PEM private key used by the runner to SSH to targets.
- `APPD_ACCOUNT_ACCESS_KEY`: AppDynamics account access key. Do not store this
  as a repository variable.
- `CLIENT_INVENTORY_API_TOKEN`: token sent in the `X-SF-Token` header for
  Client Inventory API checks. This is separate from `APPD_ACCOUNT_ACCESS_KEY`.

If `ACCOUNT_ACCESS_KEY` exists as an Actions variable, delete it after creating
the secret. The key was historically committed, so rotate it in AppDynamics and
rewrite git history before treating this repository as clean.

### GitHub Variables

Set these in **Settings -> Secrets and variables -> Actions -> Variables**:

- `DEPLOYMENT_HOSTS`: one target hostname or private IP per line.
- `SSH_USER`: optional target SSH user. Defaults to `ubuntu`.
- `SMARTAGENT_USER`: optional service user for Smart Agent.
- `SMARTAGENT_GROUP`: optional service group for Smart Agent.
- `CLIENT_INVENTORY_API_BASE_URL`: optional Client Inventory API base URL.
  Defaults to `https://<ControllerURL from config.ini>/fm-service/v1`.
- `CLIENT_INVENTORY_SAMPLE_SIZE`: optional number of clients sampled by API
  checks. Defaults to `1`.

`SMARTAGENT_USER` and `SMARTAGENT_GROUP` must be set together.

### Runner Prerequisites

The self-hosted runner needs:

- `bash`
- `jq`
- `sha256sum`
- `ssh`, `scp`, and `ssh-keyscan`

The deploy workflow installs `unzip` on targets with `apt-get` before extracting
the Smart Agent package.

## Client Inventory API Checks

`openapi.json` documents the Client Inventory API used for review-time API
validation. The checker validates the spec and exercises:

- `GET /clients`
- `GET /clients/{id}`
- `GET /clients/{id}/config`
- `POST /clients/configs:batch`

The standalone `12. Check Client Inventory API` workflow can fail when the live
API, URL, or token is wrong. The 11 lifecycle workflows run the same check after
their lifecycle action in warning-only mode so API readiness is visible without
blocking deploy/install/uninstall/cleanup while no test cluster is available.

## Workflows

The repository contains 12 manual workflows:

- `1. Deploy Smart Agent`
- `2. Install Machine Agent`
- `3. Install Java Agent`
- `4. Install Node Agent`
- `5. Install Database Agent`
- `6. Stop and Clean Smart Agent`
- `7. Uninstall Machine Agent`
- `8. Uninstall Java Agent`
- `9. Uninstall Node Agent`
- `10. Uninstall Database Agent`
- `11. Cleanup Smart Agent Directory`
- `12. Check Client Inventory API`

All workflows accept a numeric `batch_size` input from `1` to `256`; the default
is `256`.

Example:

```bash
gh workflow run "1. Deploy Smart Agent" \
  --repo chambear2809/github-actions-lab \
  -f batch_size=128
```

## How Deployment Works

1. The prepare job validates `DEPLOYMENT_HOSTS`, rejects empty or duplicate
   host lists, validates `batch_size`, and emits a batch matrix.
2. The batch job checks out the repository and runs the shared workflow script.
3. The deploy script verifies the Smart Agent zip checksum using
   `.github/checksums/appdsmartagent_64_linux_25.12.0.661.zip.sha256`.
4. The deploy script writes a temporary `config.ini` with
   `APPD_ACCOUNT_ACCESS_KEY` substituted for `{{ACCOUNT_ACCESS_KEY}}`.
5. For each host, the script gathers the SSH host key into a per-run
   `known_hosts` file, copies the zip and config to `/tmp`, extracts into
   `/opt/appdynamics/appdsmartagent`, fixes ownership, and starts the service.

The install, uninstall, stop-clean, and directory-cleanup workflows use the same
validated batching and SSH path. All lifecycle workflows also run a warning-only
Client Inventory API check after the lifecycle action completes.

## Security Notes

- Rotate the historical AppDynamics access key before using this repository for
  real environments.
- Store the replacement in `APPD_ACCOUNT_ACCESS_KEY`, not `ACCOUNT_ACCESS_KEY`.
- Store the Client Inventory API token in `CLIENT_INVENTORY_API_TOKEN`; do not
  reuse `APPD_ACCOUNT_ACCESS_KEY` for this API.
- The workflows use per-run host-key discovery. For production, replace this
  with pinned host keys or an internal SSH CA so host identity is independently
  trusted.
- Keep workflow file changes protected with branch protection and review
  requirements.
- Keep the runner and targets on private addresses. See `AWS_REMEDIATION.md`
  for the current environment drift and proposed remediation sequence.

## Maintenance

### Updating Smart Agent

1. Replace `appdsmartagent_64_linux_25.12.0.661.zip`.
2. Update `.github/checksums/<zip-name>.sha256`.
3. Run:

   ```bash
   shasum -a 256 appdsmartagent_64_linux_25.12.0.661.zip
   ```

4. Commit the new zip, checksum, and any config updates.

### Validating Locally

Run these checks before pushing:

```bash
jq empty openapi.json
yamllint .github/workflows/*.yml
shellcheck .github/scripts/*.sh
bash .github/scripts/test-create-batches.sh
bash .github/scripts/test-client-inventory-api.sh
```

Install and run `actionlint` as an additional GitHub Actions syntax check when
available.
