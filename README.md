# AppDynamics Smart Agent Management with GitHub Actions

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=flat&logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![AppDynamics](https://img.shields.io/badge/AppDynamics-0078D4?style=flat)](https://www.appdynamics.com/)

Automated deployment and lifecycle management of AppDynamics Smart Agent across multiple EC2 hosts using GitHub Actions with a self-hosted runner.

## 🎯 Overview

This lab demonstrates how to use GitHub Actions to manage AppDynamics Smart Agent and various AppDynamics agents (Node, Machine, DB, Java) across multiple Ubuntu EC2 instances within a single AWS VPC. The project includes 11 automated workflows covering the complete agent lifecycle.

**Key Features:**
- 🚀 **Parallel Deployment** - Deploy to multiple hosts simultaneously
- 🔄 **Complete Lifecycle Management** - Install, uninstall, stop, and clean agents
- 🏗️ **Infrastructure as Code** - All workflows version-controlled
- 🔐 **Secure** - SSH key-based authentication, private VPC networking
- 📈 **Massively Scalable** - Deploy to thousands of hosts with automatic batching
- 🎛️ **Self-hosted Runner** - Executes within your AWS VPC

## 📊 Architecture

All infrastructure runs in a single AWS VPC with a shared security group. The self-hosted runner communicates with target hosts via private IPs.

[View detailed architecture diagrams →](ARCHITECTURE.md)

## 🚀 Quick Start

### Prerequisites
- AWS VPC with EC2 instances (Ubuntu)
- Self-hosted GitHub Actions runner in the same VPC
- SSH key pair for authentication
- AppDynamics Smart Agent package and config

### 1️⃣ Clone and Configure

```bash
git clone https://github.com/chambear2809/github-actions-lab.git
cd github-actions-lab
```

### 2️⃣ Set Up GitHub Secrets

Navigate to: **Settings → Secrets and variables → Actions**

**Required Secret:**
- `SSH_PRIVATE_KEY` - Your SSH private key (PEM format)

### 3️⃣ Set Up GitHub Variables

Navigate to: **Settings → Secrets and variables → Actions → Variables**

**Required Variable:**
- `DEPLOYMENT_HOSTS` - Target host IPs (one per line)
  ```
  172.31.1.243
  172.31.1.48
  172.31.1.5
  ```

**Optional Variables:**
- `SMARTAGENT_USER` - User for Smart Agent service (e.g., `appdynamics`)
- `SMARTAGENT_GROUP` - Group for Smart Agent service (e.g., `appdynamics`)

### 4️⃣ Deploy!

**Via GitHub UI:**
1. Go to **Actions** tab
2. Select **"Deploy Smart Agent"**
3. Click **"Run workflow"**
4. Optionally adjust batch size (default: 256)
5. Click **"Run workflow"**

**Via GitHub CLI:**
```bash
gh workflow run "Deploy Smart Agent" --repo chambear2809/github-actions-lab

# With custom batch size
gh workflow run "Deploy Smart Agent" --repo chambear2809/github-actions-lab -f batch_size=128
```

## 📋 Available Workflows

### Deployment (1 workflow)
| Workflow | Description | Scale | Trigger |
|----------|-------------|-------|----------|
| **Deploy Smart Agent (Batched)** | Installs Smart Agent and starts service | Any | Manual only |

### Agent Installation (4 batched workflows)
| Workflow | Command | Scale | Trigger |
|----------|---------|-------|----------|
| **Install Node Agent (Batched)** | `smartagentctl install node` | Any | Manual only |
| **Install Machine Agent (Batched)** | `smartagentctl install machine` | Any | Manual only |
| **Install DB Agent (Batched)** | `smartagentctl install db` | Any | Manual only |
| **Install Java Agent (Batched)** | `smartagentctl install java` | Any | Manual only |

### Agent Uninstallation (4 batched workflows)
| Workflow | Command | Scale | Trigger |
|----------|---------|-------|----------|
| **Uninstall Node Agent (Batched)** | `smartagentctl uninstall node` | Any | Manual only |
| **Uninstall Machine Agent (Batched)** | `smartagentctl uninstall machine` | Any | Manual only |
| **Uninstall DB Agent (Batched)** | `smartagentctl uninstall db` | Any | Manual only |
| **Uninstall Java Agent (Batched)** | `smartagentctl uninstall java` | Any | Manual only |

### Smart Agent Management (2 batched workflows)
| Workflow | Description | Scale | Trigger |
|----------|-------------|-------|----------|
| **Stop and Clean Smart Agent (Batched)** | Stops service and purges data | Any | Manual only |
| **Cleanup All Agents (Batched)** | Deletes /opt/appdynamics directory | Any | Manual only |

**Total: 11 workflows** - All batched workflows support configurable batch sizes (default: 256)

## 📚 Documentation

- **[Deployment Guide](DEPLOYMENT_GUIDE.md)** - Complete setup and configuration instructions
- **[Architecture Diagrams](ARCHITECTURE.md)** - Visual infrastructure and workflow diagrams

## 🛠️ How It Works

1. **Developer** pushes code or manually triggers a workflow
2. **GitHub Actions** receives the event and assigns job to self-hosted runner
3. **Runner** loads target hosts from GitHub variables
4. **Parallel Execution** - Runner SSHs into each target host simultaneously
5. **Commands Execute** - Install/uninstall/stop/clean operations run on each host
6. **Results Reported** - Success/failure status sent back to GitHub

## 🔐 Security

- **Private Network** - All communication via VPC private IPs
- **SSH Keys** - Stored securely as GitHub secrets
- **No Public Access** - Target hosts don't need public IPs
- **Security Group** - Restricts SSH access to runner only

## 📈 Scaling

All workflows use automatic batching to support any number of hosts:

### How It Works
- **Automatic batching** - Splits hosts into groups of 256 (configurable)
- **Sequential batch processing** - Avoids overwhelming runner resources
- **Parallel within batch** - Each batch processes all hosts simultaneously
- **Works at any scale** - 1 host to thousands

### Batching Strategy
1. Splits your host list into manageable batches
2. Processes each batch as a separate job sequentially
3. Deploys to all hosts within each batch in parallel using background processes

**Examples:**
- **10 hosts** = 1 batch, all deploy in parallel
- **500 hosts** = 2 batches × 256 hosts
- **1,000 hosts** = 4 batches × 256 hosts
- **5,000 hosts** = 20 batches × 256 hosts

## 🤝 Contributing

This is a lab/demo project. Feel free to fork and adapt for your own use cases!

## 📝 License

MIT License - See [LICENSE](LICENSE) for details

## 🔗 Links

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AppDynamics Documentation](https://docs.appdynamics.com/)
- [Self-hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)

---

**Built with ❤️ for AppDynamics automation**
