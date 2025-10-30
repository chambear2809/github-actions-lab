# AppDynamics Smart Agent Deployment Guide

## Overview
This guide documents the automated deployment of AppDynamics Smart Agent to multiple Ubuntu hosts using GitHub Actions with a self-hosted runner.

## Architecture

### Components
- **GitHub Actions Workflow**: Orchestrates deployment across multiple hosts
- **Self-hosted Runner**: Executes workflows from within your VPC
- **Target Hosts**: Ubuntu servers receiving the AppDynamics Smart Agent
- **GitHub Repository**: Stores workflow configuration and deployment artifacts

### Workflow Design
The deployment uses a two-job approach:
1. **Prepare Job**: Loads target hosts from GitHub variables and creates a dynamic matrix
2. **Deploy Job**: Runs in parallel for each host, deploying the agent

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

### 7. Network Configuration

Ensure the self-hosted runner can reach target hosts:
- Runner security group: Allow outbound SSH (port 22) to target hosts
- Target host security groups: Allow inbound SSH (port 22) from runner
- Runner requires outbound HTTPS (port 443) to GitHub

## Deployment Process

### Manual Trigger
```bash
gh workflow run "Deploy AppDynamics Smart Agent" --repo YOUR_USERNAME/YOUR_REPO
```

Or trigger via GitHub UI:
1. Go to **Actions** tab
2. Select **"Deploy AppDynamics Smart Agent"**
3. Click **"Run workflow"**

### Automatic Trigger
Push to the `main` branch automatically triggers deployment:
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
│       └── deploy-agent.yml
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
