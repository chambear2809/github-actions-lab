# AppDynamics Smart Agent Deployment

GitHub Actions workflow to deploy AppDynamics Smart Agent to multiple EC2 hosts.

## Setup

### 1. Add Required Files
Place these files in the repository root:
- `appdsmartagent_64_linux_25.10.0.497.zip`
- `config.ini`

### 2. Configure GitHub Secret
Your SSH key has been copied to clipboard. Add it as a GitHub secret:

1. Create a GitHub repository and push this code
2. Go to: Repository → Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `SSH_PRIVATE_KEY`
5. Paste the key from your clipboard
6. Click "Add secret"

### 3. Run the Workflow
- Automatically triggers on push to `main` branch
- Or manually trigger from: Actions → Deploy AppDynamics Smart Agent → Run workflow

## Target Hosts
- ec2-54-87-218-158.compute-1.amazonaws.com
- ec2-204-236-198-70.compute-1.amazonaws.com
- ec2-3-81-228-67.compute-1.amazonaws.com
