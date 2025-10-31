# Architecture Diagram

## Lab Infrastructure Overview

```mermaid
graph TB
    subgraph Internet
        GH[GitHub.com<br/>Repository & Actions]
        User[Developer<br/>Local Machine]
    end

    subgraph AWS["AWS VPC (172.31.0.0/16)"]
        subgraph SG["Security Group: smartagent-lab"]
            Runner[Self-hosted Runner<br/>EC2 Instance<br/>172.31.1.x]
            
            subgraph Targets["Target Hosts"]
                T1[Target Host 1<br/>Ubuntu EC2<br/>172.31.1.243]
                T2[Target Host 2<br/>Ubuntu EC2<br/>172.31.1.48]
                T3[Target Host 3<br/>Ubuntu EC2<br/>172.31.1.5]
            end
        end
    end

    User -->|git push| GH
    GH <-->|HTTPS:443<br/>Poll for jobs| Runner
    Runner -->|SSH:22<br/>Private IPs| T1
    Runner -->|SSH:22<br/>Private IPs| T2
    Runner -->|SSH:22<br/>Private IPs| T3

    style GH fill:#24292e,color:#fff
    style User fill:#0366d6,color:#fff
    style Runner fill:#28a745,color:#fff
    style T1 fill:#ffd33d,color:#000
    style T2 fill:#ffd33d,color:#000
    style T3 fill:#ffd33d,color:#000
    style AWS fill:#FF9900,color:#fff,stroke:#232F3E,stroke-width:3px
    style SG fill:#EC7211,color:#fff,stroke:#232F3E,stroke-width:2px
```

## Workflow Execution Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant Runner as Self-hosted Runner
    participant Target as Target Host(s)

    Dev->>GH: 1. Push code or trigger workflow
    GH->>GH: 2. Workflow event triggered
    Runner->>GH: 3. Poll for jobs (HTTPS:443)
    GH->>Runner: 4. Assign job to runner
    Runner->>Runner: 5. Execute prepare job<br/>(load host matrix)
    
    par Parallel Execution
        Runner->>Target: 6a. SSH to Host 1<br/>(port 22)
        Runner->>Target: 6b. SSH to Host 2<br/>(port 22)
        Runner->>Target: 6c. SSH to Host 3<br/>(port 22)
    end
    
    Target->>Target: 7. Execute commands<br/>(install/uninstall/stop/clean)
    Target-->>Runner: 8. Return results
    Runner-->>GH: 9. Report job status
    GH-->>Dev: 10. Notify completion
```

## Network Communication

```mermaid
graph LR
    subgraph "Security Group Rules"
        direction TB
        IN["Inbound Rules"]
        OUT["Outbound Rules"]
    end

    subgraph "Allowed Traffic"
        SSH["SSH (22)<br/>Source: Same SG<br/>For runner → targets"]
        HTTPS["HTTPS (443)<br/>Destination: 0.0.0.0/0<br/>For GitHub API"]
    end

    IN -.-> SSH
    OUT -.-> SSH
    OUT -.-> HTTPS

    style IN fill:#e1f5fe,color:#000
    style OUT fill:#fff3e0,color:#000
    style SSH fill:#c8e6c9,color:#000
    style HTTPS fill:#c8e6c9,color:#000
```

## Workflow Categories

```mermaid
graph TD
    Root[GitHub Actions Workflows<br/>11 Total]
    
    Root --> Deploy[Deployment<br/>1 workflow]
    Root --> Install[Agent Installation<br/>4 batched workflows]
    Root --> Uninstall[Agent Uninstallation<br/>4 batched workflows]
    Root --> Manage[Smart Agent Management<br/>2 batched workflows]

    Deploy --> D1[Deploy Smart Agent<br/>Batched, Manual trigger]
    
    Install --> I1[Install Node<br/>Batched]
    Install --> I2[Install Machine<br/>Batched]
    Install --> I3[Install DB<br/>Batched]
    Install --> I4[Install Java<br/>Batched]
    
    Uninstall --> U1[Uninstall Node<br/>Batched]
    Uninstall --> U2[Uninstall Machine<br/>Batched]
    Uninstall --> U3[Uninstall DB<br/>Batched]
    Uninstall --> U4[Uninstall Java<br/>Batched]
    
    Manage --> M1[Stop and Clean<br/>Batched]
    Manage --> M2[Cleanup All Agents<br/>Batched]

    style Root fill:#6f42c1,color:#fff
    style Deploy fill:#28a745,color:#fff
    style Install fill:#0366d6,color:#fff
    style Uninstall fill:#dc3545,color:#fff
    style Manage fill:#fd7e14,color:#fff
```

## Data Flow

```mermaid
graph LR
    subgraph "GitHub Repository"
        WF[Workflow Files]
        ZIP[Smart Agent ZIP]
        CFG[config.ini]
        SEC[Secrets/Variables]
    end

    subgraph "Runner Execution"
        PREP[Prepare Job]
        MATRIX[Host Matrix]
    end

    subgraph "Target Hosts"
        TMP[/tmp/]
        OPT[/opt/appdynamics/]
    end

    WF --> PREP
    SEC --> PREP
    PREP --> MATRIX

    ZIP --> TMP
    CFG --> TMP
    TMP --> OPT
    
    OPT --> AGENT[Smart Agent<br/>Running]

    style WF fill:#24292e,color:#fff
    style ZIP fill:#f6c6be,color:#000
    style CFG fill:#bae8e8,color:#000
    style SEC fill:#e63946,color:#fff
    style AGENT fill:#28a745,color:#fff
```

## Component Details

### Self-hosted Runner
- **OS**: Ubuntu/Amazon Linux 2
- **Role**: Executes GitHub Actions workflows
- **Access**: 
  - Outbound HTTPS (443) to GitHub
  - Outbound SSH (22) to target hosts
  - Uses SSH key authentication

### Target Hosts
- **OS**: Ubuntu Server
- **Deployed Components**:
  - Smart Agent (`/opt/appdynamics/`)
  - AppDynamics Agents (node, machine, db, java)
- **Access**: 
  - Inbound SSH (22) from runner only
  - Private IP communication only

### GitHub Repository
- **Stores**:
  - 11 workflow YAML files
  - Smart Agent installation package
  - Configuration file (config.ini)
- **Secrets**: SSH private key
- **Variables**: Host list, user/group settings

## Scaling Considerations

```mermaid
graph TD
    A[Number of Hosts]
    A -->|Any| C[Batched Workflow<br/>deploy-agent-batched.yml]
    
    C --> E[Prepare Job<br/>Split into batches]
    E --> F[Batch 1: 256 hosts<br/>Parallel deployment]
    E --> G[Batch 2: 256 hosts<br/>Parallel deployment]
    E --> H[Batch N: Remaining hosts<br/>Parallel deployment]
    
    F --> I[Sequential Execution<br/>One batch at a time]
    G --> I
    H --> I
    
    style A fill:#0366d6,color:#fff
    style C fill:#28a745,color:#fff
    style E fill:#e1bee7,color:#000
    style F fill:#fff3e0,color:#000
    style G fill:#fff3e0,color:#000
    style H fill:#fff3e0,color:#000
    style I fill:#ffccbc,color:#000
```

## Batched Workflow Architecture

### How It Works

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub Actions
    participant Prep as Prepare Job
    participant B1 as Batch 1 (256 hosts)
    participant B2 as Batch 2 (256 hosts)
    participant BN as Batch N (remaining)

    Dev->>GH: Trigger batched workflow
    GH->>Prep: Start prepare job
    Prep->>Prep: Load DEPLOYMENT_HOSTS variable
    Prep->>Prep: Split into batches of 256
    Prep->>Prep: Create batch matrix JSON
    
    Prep-->>GH: Output: batches array
    
    GH->>B1: Deploy batch 1 (sequential)
    Note over B1: 256 parallel SSH connections
    B1-->>GH: Batch 1 complete ✓
    
    GH->>B2: Deploy batch 2 (sequential)
    Note over B2: 256 parallel SSH connections
    B2-->>GH: Batch 2 complete ✓
    
    GH->>BN: Deploy batch N (sequential)
    Note over BN: Remaining hosts in parallel
    BN-->>GH: Batch N complete ✓
    
    GH-->>Dev: All batches deployed 🎉
```

### Why Sequential Batches?

**Resource Management:**
- Prevents overwhelming the self-hosted runner
- Each batch opens 256 parallel SSH connections
- Sequential processing ensures stable performance

**Configurable:**
- Default batch size: 256 (GitHub Actions matrix limit)
- Adjustable via workflow input for smaller batches
- Balance between speed and resource usage

---

**Note**: All diagrams are written in Mermaid syntax and will render automatically on GitHub.
