# AZ-104 Lab Landing Zone — Architecture Guide

## Overview

This landing zone provides a low-cost Azure lab environment designed for hands-on practice
of AZ-104 exam topics. Every component maps directly to an exam domain.

## Exam Domain Mapping

| Component            | AZ-104 Domain                                      | Weight |
|----------------------|-----------------------------------------------------|--------|
| VNet, Subnets, NSGs  | Configure and manage virtual networking             | 25-30% |
| Azure Bastion        | Secure access to virtual networks                   | 25-30% |
| Linux VM, NIC, Disk  | Deploy and manage Azure compute resources           | 20-25% |
| Storage Account      | Configure and manage storage accounts               | 15-20% |
| RBAC Roles           | Manage Azure identities and governance              | 15-20% |
| Log Analytics, Monitor| Monitor and maintain Azure resources               | 10-15% |

## Architecture Diagram

    ┌─────────────────────────────────────────────────────────────────┐
    │                    Azure Subscription                           │
    │                                                                 │
    │  ┌───────────────────────────────────────────────────────────┐  │
    │  │              rg-lab-dev-cac-001 (Canada Central)                 │  │
    │  │                                                           │  │
    │  │  ┌─────────────────────────────────────────────────────┐  │  │
    │  │  │          vnet-lab-dev-cac-001 (10.0.0.0/16)         │  │  │
    │  │  │                                                     │  │  │
    │  │  │  ┌──────────────────┐  ┌─────────────────────────┐  │  │  │
    │  │  │  │ AzureBastionSnet │  │   snet-vms-dev-cac-001  │  │  │  │
    │  │  │  │   10.0.0.0/26    │  │      10.0.1.0/24        │  │  │  │
    │  │  │  │  ┌────────────┐  │  │  ┌───────────────────┐  │  │  │  │
    │  │  │  │  │  Bastion    │──│──│─▶│  vm-lab-dev-cac   │  │  │  │  │
    │  │  │  │  │  (Basic)    │  │  │  │  Ubuntu 22.04     │  │  │  │  │
    │  │  │  │  └────────────┘  │  │  │  B2ats_v2 / SSH  │  │  │  │  │
    │  │  │  └──────────────────┘  │  └───────────────────┘  │  │  │  │
    │  │  │                        │  nsg-vms: Bastion→22    │  │  │  │
    │  │  │                        └─────────────────────────┘  │  │  │
    │  │  │  ┌─────────────────────────────┐                    │  │  │
    │  │  │  │  snet-services-dev-cac-001  │                    │  │  │
    │  │  │  │       10.0.2.0/24           │                    │  │  │
    │  │  │  │  nsg-services: VNet only    │                    │  │  │
    │  │  │  └─────────────────────────────┘                    │  │  │
    │  │  └─────────────────────────────────────────────────────┘  │  │
    │  │                                                           │  │
    │  │  ┌──────────────────┐  ┌──────────────────────────────┐   │  │
    │  │  │ stlabdevcac001   │  │ law-lab-dev-cac-001          │   │  │
    │  │  │ StorageV2 / LRS  │  │ Log Analytics (30d)          │   │  │
    │  │  │ Boot diagnostics │  │ Azure Monitor Agent          │   │  │
    │  │  └──────────────────┘  └──────────────────────────────┘   │  │
    │  └───────────────────────────────────────────────────────────┘  │
    │                                                                 │
    │  RBAC: Contributor │ Reader │ VM Contributor                    │
    └─────────────────────────────────────────────────────────────────┘

## Component Details

### Networking Layer

**VNet (vnet-lab-dev-cac-001):** Single virtual network with /16 address space providing
network isolation. Three subnets separate concerns: Bastion access, VM workloads, and
backend services.

**NSGs:** Explicit deny-all rules with specific allow exceptions. The VMs NSG only allows
SSH from the Bastion subnet. The Services NSG allows intra-VNet traffic only.

**Azure Bastion (bas-lab-dev-cac-001):** Provides browser-based SSH access to VMs without
exposing public IPs. Basic SKU keeps costs low while covering exam topics.

### Compute Layer

**Linux VM (vm-lab-dev-cac-001):** Ubuntu 22.04 LTS on B2ats_v2 (2 vCPUs, 1GB RAM, burstable). SSH key
authentication only — no passwords. Azure Monitor Agent extension installed for monitoring.

### Management Layer

**Storage Account (stlabdevcac001):** Standard LRS with a blob container for exercises.
Used for VM boot diagnostics. TLS 1.2 enforced, public blob access disabled.

**Log Analytics (law-lab-dev-cac-001):** Centralized log collection with 30-day retention
(free tier). Receives VM metrics via Azure Monitor Agent.

**RBAC:** Three role assignments demonstrate least-privilege access patterns:
- **Contributor** — full resource management within the RG
- **Reader** — view-only access for audit practice
- **VM Contributor** — granular role scoped to VM operations only

## Naming Convention

Pattern: `{resource-type}-{workload}-{environment}-{region}-{instance}`

| Abbreviation | Meaning     |
|--------------|-------------|
| `lab`        | Workload    |
| `dev`        | Environment |
| `cac`        | Canada Central |
| `001`        | Instance    |

Exception: Storage accounts don't allow hyphens → `stlabdevcac001`

## Cost Estimate

| Resource        | SKU/Tier          | Estimated Monthly Cost |
|-----------------|-------------------|----------------------|
| VM (B2ats_v2) | Burstable         | ~$6/mo               |
| Bastion Basic   | Basic             | ~$140/mo while active|
| Storage (LRS)   | Standard          | ~$0.50               |
| Log Analytics   | 30d free tier     | ~$0                  |
| Public IP       | Standard (static) | ~$3.65               |
| **Total**       |                   | **~$10-$150/mo**     |

> **Cost tip:** Bastion is the main cost driver. Delete it when not in use and redeploy
> when needed. Alternatively, remove the Bastion module and use SSH with a public IP + NSG
> for a near-free lab.

## Cleanup

Delete everything with one command:

    az group delete --name rg-lab-dev-cac-001 --yes --no-wait
