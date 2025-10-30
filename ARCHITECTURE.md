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
    Root[GitHub Actions Workflows<br/>13 Total]
    
    Root --> Deploy[Initial Deployment<br/>1 workflow]
    Root --> Install[Agent Installation<br/>4 workflows]
    Root --> Uninstall[Agent Uninstallation<br/>4 workflows]
    Root --> Manage[Smart Agent Management<br/>1 workflow]

    Deploy --> D1[Deploy AppDynamics<br/>Smart Agent]
    
    Install --> I1[Install Node Agent]
    Install --> I2[Install Machine Agent]
    Install --> I3[Install DB Agent]
    Install --> I4[Install Java Agent]
    
    Uninstall --> U1[Uninstall Node Agent]
    Uninstall --> U2[Uninstall Machine Agent]
    Uninstall --> U3[Uninstall DB Agent]
    Uninstall --> U4[Uninstall Java Agent]
    
    Manage --> M1[Stop and Clean<br/>Smart Agent]

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
  - 10 workflow YAML files
  - Smart Agent installation package
  - Configuration file (config.ini)
- **Secrets**: SSH private key
- **Variables**: Host list, user/group settings

## Scaling Considerations

```mermaid
graph TD
    A[Number of Hosts]
    A -->|"≤ 256"| B[Single Workflow Run<br/>GitHub matrix strategy]
    A -->|"> 256"| C[Multiple Runs or Batching]
    
    B --> D[All hosts execute in parallel]
    C --> E[Batch 1: Hosts 1-256]
    C --> F[Batch 2: Hosts 257-512]
    C --> G[Batch N...]

    style A fill:#0366d6,color:#fff
    style B fill:#28a745,color:#fff
    style C fill:#ffd33d,color:#000
    style D fill:#c8e6c9,color:#000
    style E fill:#fff3e0,color:#000
    style F fill:#fff3e0,color:#000
    style G fill:#fff3e0,color:#000
```

---

**Note**: All diagrams are written in Mermaid syntax and will render automatically on GitHub.
