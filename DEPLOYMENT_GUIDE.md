# AppDynamics Smart Agent Deployment Guide

## Overview
This guide documents the automated deployment of AppDynamics Smart Agent to multiple Ubuntu hosts using GitHub Actions with a self-hosted runner.

## Architecture

### Lab Setup
This lab demonstrates automated AppDynamics Smart Agent management across multiple EC2 instances:

- **AWS Environment**: All resources deployed in a single AWS VPC
- **Security Group**: All EC2 instances (runner and targets) share the same security group
- **Self-hosted Runner**: One EC2 instance running the GitHub Actions runner
- **Target Hosts**: Multiple Ubuntu EC2 instances within the same VPC
- **Network Access**: Private IP communication between runner and targets via port 22 (SSH)

### Components
- **GitHub Actions Workflows**: 13 workflows orchestrating agent lifecycle management
- **Self-hosted Runner**: EC2 instance executing workflows from within the VPC
- **Target Hosts**: Ubuntu EC2 servers receiving AppDynamics agents
- **GitHub Repository**: Stores workflow configurations and deployment artifacts

### Workflow Design
All workflows use a consistent two-job approach:
1. **Prepare Job**: Loads target hosts from GitHub variables and creates a dynamic matrix
2. **Action Job**: Runs in parallel for each host, executing the specific operation

## Prerequisites

### Infrastructure
- AWS VPC with EC2 instances
- Self-hosted GitHub Actions runner deployed in the same VPC
- Target Ubuntu hosts with SSH access from the runner
- SSH key pair (PEM file) for authentication

### Software
- GitHub account with repository access
- AWS account with EC2 instances
- GitHub CLI (`gh`) for management (optional)

## Setup Steps

### 1. Repository Setup

Create a new GitHub repository:
```bash
mkdir github-action-lab
cd github-action-lab
git init
```

### 2. Create Workflow File

Create the GitHub Actions workflow at `.github/workflows/deploy-agent.yml`:

```yaml
name: Deploy AppDynamics Smart Agent

on:
  workflow_dispatch:  # Manual trigger
  push:
    branches:
      - main

jobs:
  prepare:
    runs-on: self-hosted
    outputs:
      hosts: ${{ steps.set-matrix.outputs.hosts }}
    steps:
      - id: set-matrix
        run: |
          HOSTS=$(echo "${{ vars.DEPLOYMENT_HOSTS }}" | tr -d '\r' | grep -v '^$' | xargs -n1 | jq -R . | jq -s -c .)
          echo "hosts=$HOSTS" >> $GITHUB_OUTPUT
  
  deploy:
    needs: prepare
    runs-on: self-hosted
    strategy:
      matrix:
        host: ${{ fromJson(needs.prepare.outputs.hosts) }}
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup SSH key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa
          echo "Host *" > ~/.ssh/config
          echo "  StrictHostKeyChecking no" >> ~/.ssh/config
          echo "  UserKnownHostsFile=/dev/null" >> ~/.ssh/config
          chmod 600 ~/.ssh/config

      - name: Copy agent zip to remote host
        run: |
          scp -i ~/.ssh/id_rsa appdsmartagent_64_linux_25.10.0.497.zip ubuntu@${{ matrix.host }}:/tmp/

      - name: Copy config.ini to remote host
        run: |
          scp -i ~/.ssh/id_rsa config.ini ubuntu@${{ matrix.host }}:/tmp/

      - name: Deploy and start agent
        run: |
          ssh -i ~/.ssh/id_rsa ubuntu@${{ matrix.host }} << 'EOF'
            # Install unzip if not present
            sudo apt-get update -qq
            sudo apt-get install -y unzip
            
            # Extract and deploy
            cd /tmp
            sudo mkdir -p /opt/appdynamics
            sudo unzip -o appdsmartagent_64_linux_25.10.0.497.zip -d /tmp/agent
            sudo cp -r /tmp/agent/* /opt/appdynamics/
            sudo cp config.ini /opt/appdynamics/config.ini
            
            # Start the agent
            cd /opt/appdynamics
            sudo ./smartagentctl start --enable-auto-attach --service
          EOF
```

### 3. Add Deployment Artifacts

Place these files in the repository root:
- `appdsmartagent_64_linux_25.10.0.497.zip` - AppDynamics Smart Agent package
- `config.ini` - Agent configuration file

### 4. Configure Self-Hosted Runner

#### Install Runner on EC2 Instance

1. Launch an EC2 instance in your VPC (Amazon Linux 2 or Ubuntu)
2. Navigate to repository settings: `https://github.com/YOUR_USERNAME/YOUR_REPO/settings/actions/runners/new`
3. SSH into the runner instance and execute the installation commands provided by GitHub

Example:
```bash
# Download
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure
./config.sh --url https://github.com/YOUR_USERNAME/YOUR_REPO --token YOUR_TOKEN

# Install as service
sudo ./svc.sh install
sudo ./svc.sh start
```

#### Verify Runner Status
Check that the runner appears as "Idle" (green) in:
`https://github.com/YOUR_USERNAME/YOUR_REPO/settings/actions/runners`

### 5. Configure GitHub Secrets

Navigate to: `https://github.com/YOUR_USERNAME/YOUR_REPO/settings/secrets/actions`

#### Add SSH Private Key Secret

1. Click **"New repository secret"**
2. Name: `SSH_PRIVATE_KEY`
3. Value: Paste the contents of your PEM file
   ```bash
   cat /path/to/your-key.pem
   ```
4. Click **"Add secret"**

### 6. Configure GitHub Variables

Navigate to: `https://github.com/YOUR_USERNAME/YOUR_REPO/settings/variables/actions`

#### Add Deployment Hosts Variable

1. Click **"New repository variable"**
2. Name: `DEPLOYMENT_HOSTS`
3. Value: Enter your target host IPs (one per line)
   ```
   172.31.1.243
   172.31.1.48
   172.31.1.5
   ```
4. Click **"Add variable"**

### 7. Configure Optional Variables (for Smart Agent user/group)

Navigate to: `https://github.com/YOUR_USERNAME/YOUR_REPO/settings/variables/actions`

1. Click **"New repository variable"**
2. Name: `SMARTAGENT_USER` (e.g., `appdynamics`)
3. Click **"Add variable"**
4. Repeat for `SMARTAGENT_GROUP` (e.g., `appdynamics`)

These are optional and only used during initial Smart Agent deployment.

### 8. Network Configuration

For this lab setup with all EC2 instances in the same VPC and security group:
- **Security Group Rules**:
  - Allow inbound SSH (port 22) within the security group (source: same security group)
  - Allow outbound HTTPS (port 443) to 0.0.0.0/0 (for GitHub API access)
- **Private IPs**: Use private IP addresses (172.31.x.x) for `DEPLOYMENT_HOSTS`
- **No public IPs needed**: Runner communicates with targets via private network

## Available Workflows

This repository includes 13 workflows for complete Smart Agent lifecycle management:

### Initial Deployment
1. **Deploy AppDynamics Smart Agent** - Installs Smart Agent and starts the service
   - Supports optional `--user` and `--group` parameters via GitHub variables
   - Auto-triggers on push to main, or manual via workflow_dispatch

### Agent Installation (Manual trigger only)
2. **Install Node Agent** - `smartagentctl install node`
3. **Install Machine Agent** - `smartagentctl install machine`
4. **Install DB Agent** - `smartagentctl install db`
5. **Install Java Agent** - `smartagentctl install java`

### Agent Uninstallation (Manual trigger only)
6. **Uninstall Node Agent** - `smartagentctl uninstall node`
7. **Uninstall Machine Agent** - `smartagentctl uninstall machine`
8. **Uninstall DB Agent** - `smartagentctl uninstall db`
9. **Uninstall Java Agent** - `smartagentctl uninstall java`

### Smart Agent Management (Manual trigger only)
10. **Stop and Clean Smart Agent** - `smartagentctl stop` + `smartagentctl clean`
    - Stops the Smart Agent service and purges all data

## Running Workflows

### Manual Trigger (CLI)
```bash
gh workflow run "Deploy AppDynamics Smart Agent" --repo YOUR_USERNAME/YOUR_REPO
gh workflow run "Install Node Agent" --repo YOUR_USERNAME/YOUR_REPO
gh workflow run "Uninstall Machine Agent" --repo YOUR_USERNAME/YOUR_REPO
gh workflow run "Stop and Clean Smart Agent" --repo YOUR_USERNAME/YOUR_REPO
```

### Manual Trigger (GitHub UI)
1. Go to **Actions** tab
2. Select the desired workflow from the left sidebar
3. Click **"Run workflow"**
4. Select branch (main)
5. Click **"Run workflow"**

### Automatic Trigger
Only the "Deploy AppDynamics Smart Agent" workflow auto-triggers on push to `main`:
```bash
git add .
git commit -m "Update deployment configuration"
git push origin main
```

## Monitoring and Troubleshooting

### View Workflow Status
```bash
gh run list --repo YOUR_USERNAME/YOUR_REPO
```

### View Specific Run Details
```bash
gh run view RUN_ID --repo YOUR_USERNAME/YOUR_REPO
```

### View Failed Logs
```bash
gh run view RUN_ID --log-failed --repo YOUR_USERNAME/YOUR_REPO
```

### Common Issues

#### Runner Not Picking Up Jobs
- Verify runner status: Check if it's online in repository settings
- Check runner service: `sudo systemctl status actions.runner.*`
- Verify outbound HTTPS (443) connectivity to GitHub

#### SSH Connection Failures
- Verify SSH key is correctly configured in secrets
- Ensure runner can reach target hosts on port 22
- Check security group rules

#### "hostname contains invalid characters"
- Ensure `DEPLOYMENT_HOSTS` variable has clean newline-separated IPs
- No trailing spaces or special characters

## Scaling to Thousands of Hosts

### Adding New Hosts
Simply update the `DEPLOYMENT_HOSTS` variable:
1. Go to repository variables settings
2. Edit `DEPLOYMENT_HOSTS`
3. Add new IPs (one per line)
4. Save changes

The workflow automatically processes all hosts in parallel using GitHub Actions matrix strategy.

### Performance Considerations
- GitHub Actions has a matrix limit of 256 jobs per workflow
- For >256 hosts, consider batching or multiple workflow runs
- Self-hosted runner resources scale with parallel job count

### Alternative Approaches for Large Scale
- Use multiple runners with labels for different host groups
- Implement batching logic in the workflow
- Consider complementary tools like Ansible for very large deployments

## Security Best Practices

1. **SSH Key Management**
   - Use GitHub Secrets for private keys (never commit to repository)
   - Rotate SSH keys regularly
   - Use separate keys for different environments

2. **Runner Security**
   - Keep runner in private VPC subnet
   - Restrict runner security group to minimal required access
   - Update runner software regularly

3. **Access Control**
   - Limit repository access to authorized users
   - Use branch protection rules on `main`
   - Enable required reviews for workflow changes

## Repository Structure

```
github-action-lab/
├── .github/
│   └── workflows/
│       ├── deploy-agent.yml              # Initial Smart Agent deployment
│       ├── install-node.yml              # Install node agent
│       ├── install-machine.yml           # Install machine agent
│       ├── install-db.yml                # Install db agent
│       ├── install-java.yml              # Install java agent
│       ├── uninstall-node.yml            # Uninstall node agent
│       ├── uninstall-machine.yml         # Uninstall machine agent
│       ├── uninstall-db.yml              # Uninstall db agent
│       ├── uninstall-java.yml            # Uninstall java agent
│       └── stop-clean-smartagent.yml     # Stop and clean Smart Agent
├── appdsmartagent_64_linux_25.10.0.497.zip
├── config.ini
├── hosts.txt (optional reference)
├── README.md
├── DEPLOYMENT_GUIDE.md
└── .gitignore
```

## Maintenance

### Updating Agent Version
1. Replace `appdsmartagent_64_linux_25.10.0.497.zip` with new version
2. Update filename references in workflow if version number changes
3. Commit and push to trigger deployment

### Updating Configuration
1. Modify `config.ini`
2. Commit and push
3. Workflow will deploy updated configuration to all hosts

## Repository

This deployment solution is available at:
**https://github.com/chambear2809/github-actions-lab**

Clone and adapt for your own AppDynamics Smart Agent deployments!
