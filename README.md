# AppDynamics Smart Agent Management with GitHub Actions

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=flat&logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![AppDynamics](https://img.shields.io/badge/AppDynamics-0078D4?style=flat)](https://www.appdynamics.com/)

Automated deployment and lifecycle management of AppDynamics Smart Agent across multiple EC2 hosts using GitHub Actions with a self-hosted runner.

## 🎯 Overview

This lab demonstrates how to use GitHub Actions to manage AppDynamics Smart Agent and various AppDynamics agents (Node, Machine, DB, Java) across multiple Ubuntu EC2 instances within a single AWS VPC.

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
2. Select **"Deploy AppDynamics Smart Agent"**
3. Click **"Run workflow"**

**Via GitHub CLI:**
```bash
gh workflow run "Deploy AppDynamics Smart Agent" --repo chambear2809/github-actions-lab
```

## 📋 Available Workflows

### Initial Deployment
| Workflow | Description | Scale | Trigger |
|----------|-------------|-------|----------|
| **Deploy AppDynamics Smart Agent** | Installs Smart Agent and starts service | Up to 256 hosts | Push to `main` or manual |
| **Deploy AppDynamics Smart Agent (Batched)** | Batched deployment for large-scale operations | **Thousands of hosts** | Manual only |

### Agent Installation
| Workflow | Command | Trigger |
|----------|---------|----------|
| **Install Node Agent** | `smartagentctl install node` | Manual only |
| **Install Machine Agent** | `smartagentctl install machine` | Manual only |
| **Install DB Agent** | `smartagentctl install db` | Manual only |
| **Install Java Agent** | `smartagentctl install java` | Manual only |

### Agent Uninstallation
| Workflow | Command | Trigger |
|----------|---------|----------|
| **Uninstall Node Agent** | `smartagentctl uninstall node` | Manual only |
| **Uninstall Machine Agent** | `smartagentctl uninstall machine` | Manual only |
| **Uninstall DB Agent** | `smartagentctl uninstall db` | Manual only |
| **Uninstall Java Agent** | `smartagentctl uninstall java` | Manual only |

### Smart Agent Management
| Workflow | Description | Trigger |
|----------|-------------|----------|
| **Stop and Clean Smart Agent** | Stops service and purges data | Manual only |

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

### Small to Medium Deployments (≤256 hosts)
Use **Deploy AppDynamics Smart Agent** workflow:
- Leverages GitHub Actions matrix for parallel execution
- Simple, fast, and efficient for smaller fleets

### Large-Scale Deployments (>256 hosts)
Use **Deploy AppDynamics Smart Agent (Batched)** workflow:
- **Automatic batching** - Splits hosts into groups of 256 (configurable)
- **Sequential batch processing** - Avoids overwhelming runner resources
- **Parallel within batch** - Each batch deploys to 256 hosts simultaneously
- **Proven at scale** - Designed for thousands of hosts

**Why Batching?**
GitHub Actions has a hard limit of 256 jobs per matrix. The batched workflow overcomes this by:
1. Splitting your host list into manageable batches
2. Processing each batch as a separate job
3. Deploying to all hosts within each batch in parallel

**Example:** 1,000 hosts = 4 batches × 256 hosts = 4 sequential jobs, each deploying in parallel

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
