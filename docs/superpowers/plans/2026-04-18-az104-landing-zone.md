# AZ-104 Lab Landing Zone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy a low-cost Azure landing zone with VNet, NSG, Bastion, Linux VM, Storage Account, and Azure Monitor — structured as a learning lab for the AZ-104 exam.

**Architecture:** Modular Bicep organized in three layers (networking, compute, management) orchestrated by a single `main.bicep`. Each module maps to an AZ-104 exam domain. Azure Bastion provides secure access without public IPs on VMs.

**Tech Stack:** Azure Bicep, Azure CLI, Ubuntu 22.04 LTS, Azure Bastion Basic SKU

---

## File Structure

```
az-104/
├── main.bicep                          # Orchestrator — deploys all layers via modules
├── main.bicepparam                     # Parameter file with environment values
├── modules/
│   ├── networking/
│   │   ├── vnet.bicep                  # VNet + 3 subnets (bastion, vms, services)
│   │   ├── nsg.bicep                   # NSG definitions + rules for vms and services subnets
│   │   └── bastion.bicep               # Azure Bastion Basic + public IP
│   ├── compute/
│   │   └── vm-linux.bicep              # Ubuntu VM + NIC + OS disk + boot diagnostics
│   └── management/
│       ├── storage.bicep               # Storage Account (LRS, StorageV2)
│       ├── monitoring.bicep            # Log Analytics workspace + diagnostic settings
│       └── rbac.bicep                  # Role assignments (Contributor, Reader, VM Contributor)
├── scripts/
│   └── deploy.sh                       # One-command deployment script
└── docs/
    └── architecture.md                 # Architecture explanation with AZ-104 exam mapping
```

---

### Task 1: Networking — NSG Module

**Files:**
- Create: `modules/networking/nsg.bicep`

- [ ] **Step 1: Create the NSG module file**

```bicep
// modules/networking/nsg.bicep
// Defines Network Security Groups for VMs and Services subnets
// AZ-104 relevance: Configure and manage virtual networking (25-30%)

@description('Azure region for all resources')
param location string

@description('Base name prefix for resources')
param namePrefix string

@description('Tags to apply to all resources')
param tags object = {}

// --- NSG for VMs Subnet ---
resource nsgVms 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-vms-${namePrefix}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowBastionSSHInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '10.0.0.0/26' // AzureBastionSubnet CIDR
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// --- NSG for Services Subnet ---
resource nsgServices 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-services-${namePrefix}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

@description('Resource ID of the VMs NSG')
output nsgVmsId string = nsgVms.id

@description('Resource ID of the Services NSG')
output nsgServicesId string = nsgServices.id

@description('Name of the VMs NSG')
output nsgVmsName string = nsgVms.name

@description('Name of the Services NSG')
output nsgServicesName string = nsgServices.name
```

- [ ] **Step 2: Validate syntax**

Run: `az bicep build --file modules/networking/nsg.bicep`
Expected: No errors, generates ARM template to stdout.

- [ ] **Step 3: Commit**

```bash
git add modules/networking/nsg.bicep
git commit -m "feat(networking): add NSG module with VMs and Services rules"
```

---

### Task 2: Networking — VNet Module

**Files:**
- Create: `modules/networking/vnet.bicep`

- [ ] **Step 1: Create the VNet module file**

```bicep
// modules/networking/vnet.bicep
// Defines VNet with 3 subnets: AzureBastionSubnet, VMs, Services
// AZ-104 relevance: Configure and manage virtual networking (25-30%)

@description('Azure region for all resources')
param location string

@description('Base name prefix for resources')
param namePrefix string

@description('VNet address space')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Bastion subnet CIDR (must be /26 or larger)')
param bastionSubnetPrefix string = '10.0.0.0/26'

@description('VMs subnet CIDR')
param vmsSubnetPrefix string = '10.0.1.0/24'

@description('Services subnet CIDR')
param servicesSubnetPrefix string = '10.0.2.0/24'

@description('NSG resource ID for VMs subnet')
param nsgVmsId string

@description('NSG resource ID for Services subnet')
param nsgServicesId string

@description('Tags to apply to all resources')
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'vnet-${namePrefix}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
      {
        name: 'snet-vms-${namePrefix}'
        properties: {
          addressPrefix: vmsSubnetPrefix
          networkSecurityGroup: {
            id: nsgVmsId
          }
        }
      }
      {
        name: 'snet-services-${namePrefix}'
        properties: {
          addressPrefix: servicesSubnetPrefix
          networkSecurityGroup: {
            id: nsgServicesId
          }
        }
      }
    ]
  }
}

@description('Resource ID of the VNet')
output vnetId string = vnet.id

@description('Name of the VNet')
output vnetName string = vnet.name

@description('Resource ID of the Bastion subnet')
output bastionSubnetId string = vnet.properties.subnets[0].id

@description('Resource ID of the VMs subnet')
output vmsSubnetId string = vnet.properties.subnets[1].id

@description('Resource ID of the Services subnet')
output servicesSubnetId string = vnet.properties.subnets[2].id
```

- [ ] **Step 2: Validate syntax**

Run: `az bicep build --file modules/networking/vnet.bicep`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add modules/networking/vnet.bicep
git commit -m "feat(networking): add VNet module with 3 subnets"
```

---

### Task 3: Networking — Bastion Module

**Files:**
- Create: `modules/networking/bastion.bicep`

- [ ] **Step 1: Create the Bastion module file**

```bicep
// modules/networking/bastion.bicep
// Azure Bastion Basic SKU for secure VM access without public IPs
// AZ-104 relevance: Secure access to virtual networks

@description('Azure region for all resources')
param location string

@description('Base name prefix for resources')
param namePrefix string

@description('Resource ID of the AzureBastionSubnet')
param bastionSubnetId string

@description('Tags to apply to all resources')
param tags object = {}

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: 'pip-bas-${namePrefix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-01-01' = {
  name: 'bas-${namePrefix}'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          publicIPAddress: {
            id: bastionPublicIp.id
          }
          subnet: {
            id: bastionSubnetId
          }
        }
      }
    ]
  }
}

@description('Name of the Bastion host')
output bastionName string = bastion.name

@description('Public IP address of Bastion')
output bastionPublicIpAddress string = bastionPublicIp.properties.ipAddress
```

- [ ] **Step 2: Validate syntax**

Run: `az bicep build --file modules/networking/bastion.bicep`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add modules/networking/bastion.bicep
git commit -m "feat(networking): add Azure Bastion module with Basic SKU"
```

---

### Task 4: Management — Storage Account Module

**Files:**
- Create: `modules/management/storage.bicep`

- [ ] **Step 1: Create the Storage module file**

```bicep
// modules/management/storage.bicep
// Storage Account for boot diagnostics and lab exercises
// AZ-104 relevance: Configure and manage storage accounts (15-20%)

@description('Azure region for all resources')
param location string

@description('Globally unique storage account name (3-24 chars, lowercase/numbers only)')
param storageAccountName string

@description('Tags to apply to all resources')
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Blob service — useful for practicing blob storage operations
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {}
}

// Create a container for lab exercises
resource labContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'lab-data'
  properties: {
    publicAccess: 'None'
  }
}

@description('Resource ID of the Storage Account')
output storageAccountId string = storageAccount.id

@description('Name of the Storage Account')
output storageAccountName string = storageAccount.name

@description('Primary blob endpoint')
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
```

- [ ] **Step 2: Validate syntax**

Run: `az bicep build --file modules/management/storage.bicep`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add modules/management/storage.bicep
git commit -m "feat(management): add Storage Account module with blob container"
```

---

### Task 5: Management — Monitoring Module

**Files:**
- Create: `modules/management/monitoring.bicep`

- [ ] **Step 1: Create the Monitoring module file**

```bicep
// modules/management/monitoring.bicep
// Log Analytics Workspace for centralized monitoring
// AZ-104 relevance: Monitor and maintain Azure resources (10-15%)

@description('Azure region for all resources')
param location string

@description('Base name prefix for resources')
param namePrefix string

@description('Log retention in days (30 = free tier)')
@minValue(30)
@maxValue(730)
param retentionDays int = 30

@description('Tags to apply to all resources')
param tags object = {}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${namePrefix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
  }
}

@description('Resource ID of the Log Analytics Workspace')
output workspaceId string = logAnalyticsWorkspace.id

@description('Name of the Log Analytics Workspace')
output workspaceName string = logAnalyticsWorkspace.name
```

- [ ] **Step 2: Validate syntax**

Run: `az bicep build --file modules/management/monitoring.bicep`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add modules/management/monitoring.bicep
git commit -m "feat(management): add Log Analytics workspace module"
```

---

### Task 6: Management — RBAC Module

**Files:**
- Create: `modules/management/rbac.bicep`

- [ ] **Step 1: Create the RBAC module file**

```bicep
// modules/management/rbac.bicep
// RBAC role assignments for lab practice
// AZ-104 relevance: Manage Azure identities and governance (15-20%)

@description('Principal ID to assign the Contributor role')
param contributorPrincipalId string = ''

@description('Principal ID to assign the Reader role')
param readerPrincipalId string = ''

@description('Principal ID to assign the VM Contributor role')
param vmContributorPrincipalId string = ''

// Built-in role definition IDs
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var vmContributorRoleId = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'

// Contributor role assignment
resource contributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(contributorPrincipalId)) {
  name: guid(resourceGroup().id, contributorPrincipalId, contributorRoleId)
  properties: {
    principalId: contributorPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalType: 'User'
  }
}

// Reader role assignment
resource readerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(readerPrincipalId)) {
  name: guid(resourceGroup().id, readerPrincipalId, readerRoleId)
  properties: {
    principalId: readerPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalType: 'User'
  }
}

// VM Contributor role assignment
resource vmContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(vmContributorPrincipalId)) {
  name: guid(resourceGroup().id, vmContributorPrincipalId, vmContributorRoleId)
  properties: {
    principalId: vmContributorPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmContributorRoleId)
    principalType: 'User'
  }
}
```

- [ ] **Step 2: Validate syntax**

Run: `az bicep build --file modules/management/rbac.bicep`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add modules/management/rbac.bicep
git commit -m "feat(management): add RBAC module with Contributor, Reader, VM Contributor roles"
```

---

### Task 7: Compute — Linux VM Module

**Files:**
- Create: `modules/compute/vm-linux.bicep`

- [ ] **Step 1: Create the Linux VM module file**

```bicep
// modules/compute/vm-linux.bicep
// Ubuntu 22.04 LTS VM with NIC, SSH key auth, boot diagnostics
// AZ-104 relevance: Deploy and manage Azure compute resources (20-25%)

@description('Azure region for all resources')
param location string

@description('Base name prefix for resources')
param namePrefix string

@description('Resource ID of the subnet for the VM NIC')
param subnetId string

@description('VM size (B1s is free-tier eligible)')
param vmSize string = 'Standard_B1s'

@description('Admin username for the VM')
param adminUsername string = 'azureadmin'

@description('SSH public key for authentication')
@secure()
param sshPublicKey string

@description('Resource ID of the Storage Account for boot diagnostics')
param bootDiagnosticsStorageUri string

@description('Resource ID of the Log Analytics Workspace for VM Insights')
param logAnalyticsWorkspaceId string

@description('Tags to apply to all resources')
param tags object = {}

// --- Network Interface ---
resource nic 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: 'nic-vm-${namePrefix}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

// --- Virtual Machine ---
resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-${namePrefix}'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vm-lab'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-vm-${namePrefix}'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        diskSizeGB: 30
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: bootDiagnosticsStorageUri
      }
    }
  }
}

// --- Azure Monitor Agent Extension ---
resource azureMonitorAgent 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'AzureMonitorLinuxAgent'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {}
  }
}

@description('Name of the VM')
output vmName string = vm.name

@description('Resource ID of the VM')
output vmId string = vm.id

@description('Private IP address of the VM')
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress

@description('Admin username')
output adminUsername string = adminUsername
```

- [ ] **Step 2: Validate syntax**

Run: `az bicep build --file modules/compute/vm-linux.bicep`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add modules/compute/vm-linux.bicep
git commit -m "feat(compute): add Linux VM module with NIC, SSH, boot diagnostics, AMA"
```

---

### Task 8: Main Orchestrator and Parameters

**Files:**
- Create: `main.bicep`
- Create: `main.bicepparam`

- [ ] **Step 1: Create main.bicep orchestrator**

```bicep
// main.bicep
// Orchestrator for the AZ-104 Lab Landing Zone
// Deploys: VNet, NSGs, Bastion, Linux VM, Storage, Log Analytics, RBAC
//
// Usage:
//   az deployment group create \
//     --resource-group rg-lab-dev-eus-001 \
//     --template-file main.bicep \
//     --parameters main.bicepparam

@description('Azure region for all resources')
param location string = 'eastus'

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Workload name')
param workloadName string = 'lab'

@description('Region abbreviation for naming')
param regionAbbreviation string = 'eus'

@description('SSH public key for VM authentication')
@secure()
param sshPublicKey string

@description('Globally unique storage account name')
param storageAccountName string = 'stlabdeveus001'

@description('Principal ID for Contributor role (leave empty to skip)')
param contributorPrincipalId string = ''

@description('Principal ID for Reader role (leave empty to skip)')
param readerPrincipalId string = ''

@description('Principal ID for VM Contributor role (leave empty to skip)')
param vmContributorPrincipalId string = ''

// --- Naming Convention ---
var namePrefix = '${workloadName}-${environment}-${regionAbbreviation}-001'
var tags = {
  environment: environment
  workload: workloadName
  managedBy: 'bicep'
  purpose: 'az104-lab'
}

// ===== NETWORKING LAYER =====

module nsg 'modules/networking/nsg.bicep' = {
  name: 'deploy-nsg'
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

module vnet 'modules/networking/vnet.bicep' = {
  name: 'deploy-vnet'
  params: {
    location: location
    namePrefix: namePrefix
    nsgVmsId: nsg.outputs.nsgVmsId
    nsgServicesId: nsg.outputs.nsgServicesId
    tags: tags
  }
}

module bastion 'modules/networking/bastion.bicep' = {
  name: 'deploy-bastion'
  params: {
    location: location
    namePrefix: namePrefix
    bastionSubnetId: vnet.outputs.bastionSubnetId
    tags: tags
  }
}

// ===== MANAGEMENT LAYER =====

module storage 'modules/management/storage.bicep' = {
  name: 'deploy-storage'
  params: {
    location: location
    storageAccountName: storageAccountName
    tags: tags
  }
}

module monitoring 'modules/management/monitoring.bicep' = {
  name: 'deploy-monitoring'
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

module rbac 'modules/management/rbac.bicep' = {
  name: 'deploy-rbac'
  params: {
    contributorPrincipalId: contributorPrincipalId
    readerPrincipalId: readerPrincipalId
    vmContributorPrincipalId: vmContributorPrincipalId
  }
}

// ===== COMPUTE LAYER =====

module vmLinux 'modules/compute/vm-linux.bicep' = {
  name: 'deploy-vm-linux'
  params: {
    location: location
    namePrefix: namePrefix
    subnetId: vnet.outputs.vmsSubnetId
    sshPublicKey: sshPublicKey
    bootDiagnosticsStorageUri: storage.outputs.primaryBlobEndpoint
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

// ===== OUTPUTS =====

@description('Resource Group name')
output resourceGroupName string = resourceGroup().name

@description('VNet name')
output vnetName string = vnet.outputs.vnetName

@description('Bastion host name')
output bastionName string = bastion.outputs.bastionName

@description('VM name')
output vmName string = vmLinux.outputs.vmName

@description('VM private IP')
output vmPrivateIp string = vmLinux.outputs.privateIpAddress

@description('Storage Account name')
output storageAccountNameOutput string = storage.outputs.storageAccountName

@description('Log Analytics Workspace name')
output logAnalyticsWorkspaceName string = monitoring.outputs.workspaceName

@description('Connect to VM via: az network bastion ssh --name ${bastionName} --resource-group ${resourceGroupName} --target-resource-id <vm-id> --auth-type ssh-key --username azureadmin --ssh-key <path-to-private-key>')
output connectionInstructions string = 'Use Azure Bastion to connect: Portal > VM > Connect > Bastion'
```

- [ ] **Step 2: Create main.bicepparam parameter file**

```
// main.bicepparam
// Parameter values for the AZ-104 Lab Landing Zone
// Update sshPublicKey with your actual SSH public key before deploying

using './main.bicep'

param location = 'eastus'
param environment = 'dev'
param workloadName = 'lab'
param regionAbbreviation = 'eus'
param storageAccountName = 'stlabdeveus001'

// REQUIRED: Replace with your SSH public key
// Generate one with: ssh-keygen -t ed25519 -C "az104-lab"
param sshPublicKey = readEnvironmentVariable('AZ104_SSH_PUBLIC_KEY', '')

// OPTIONAL: Set principal IDs for RBAC assignments
// Get your principal ID with: az ad signed-in-user show --query id -o tsv
param contributorPrincipalId = readEnvironmentVariable('AZ104_CONTRIBUTOR_PRINCIPAL_ID', '')
param readerPrincipalId = readEnvironmentVariable('AZ104_READER_PRINCIPAL_ID', '')
param vmContributorPrincipalId = readEnvironmentVariable('AZ104_VM_CONTRIBUTOR_PRINCIPAL_ID', '')
```

- [ ] **Step 3: Validate main.bicep syntax**

Run: `az bicep build --file main.bicep`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add main.bicep main.bicepparam
git commit -m "feat: add main orchestrator and parameter file"
```

---

### Task 9: Deployment Script

**Files:**
- Create: `scripts/deploy.sh`

- [ ] **Step 1: Create the deployment script**

```bash
#!/usr/bin/env bash
# scripts/deploy.sh
# One-command deployment for the AZ-104 Lab Landing Zone
#
# Prerequisites:
#   1. Azure CLI installed and logged in (az login)
#   2. SSH key generated: ssh-keygen -t ed25519 -C "az104-lab"
#   3. Set environment variable: export AZ104_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
#
# Usage:
#   chmod +x scripts/deploy.sh
#   ./scripts/deploy.sh

set -euo pipefail

# --- Configuration ---
RESOURCE_GROUP="rg-lab-dev-eus-001"
LOCATION="eastus"
TEMPLATE_FILE="main.bicep"
PARAMS_FILE="main.bicepparam"

# --- Color output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Pre-flight checks ---
log_info "Running pre-flight checks..."

if ! command -v az &> /dev/null; then
    log_error "Azure CLI not found. Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

if ! az account show &> /dev/null; then
    log_error "Not logged in. Run: az login"
    exit 1
fi

if [ -z "${AZ104_SSH_PUBLIC_KEY:-}" ]; then
    log_error "SSH public key not set. Run: export AZ104_SSH_PUBLIC_KEY=\"\$(cat ~/.ssh/id_ed25519.pub)\""
    exit 1
fi

# --- Show current context ---
ACCOUNT_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
log_info "Subscription: ${ACCOUNT_NAME} (${SUBSCRIPTION_ID})"
log_info "Resource Group: ${RESOURCE_GROUP}"
log_info "Location: ${LOCATION}"

echo ""
read -p "Continue with deployment? (y/N): " CONFIRM
if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
    log_warn "Deployment cancelled."
    exit 0
fi

# --- Create Resource Group ---
log_info "Creating resource group: ${RESOURCE_GROUP}..."
az group create \
    --name "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --tags environment=dev workload=lab managedBy=bicep purpose=az104-lab \
    --output none

# --- Deploy Bicep template ---
log_info "Deploying landing zone (this takes ~10-15 minutes due to Bastion)..."
az deployment group create \
    --resource-group "${RESOURCE_GROUP}" \
    --template-file "${TEMPLATE_FILE}" \
    --parameters "${PARAMS_FILE}" \
    --name "az104-lab-$(date +%Y%m%d-%H%M%S)" \
    --output table

log_info "Deployment complete!"

# --- Show outputs ---
echo ""
log_info "=== Deployment Summary ==="
az deployment group show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "$(az deployment group list --resource-group ${RESOURCE_GROUP} --query '[0].name' -o tsv)" \
    --query properties.outputs \
    --output table

echo ""
log_info "=== Next Steps ==="
echo "  1. Connect to VM via Bastion:"
echo "     az network bastion ssh --name bas-lab-dev-eus-001 --resource-group ${RESOURCE_GROUP} --target-resource-id <vm-resource-id> --auth-type ssh-key --username azureadmin --ssh-key ~/.ssh/id_ed25519"
echo ""
echo "  2. Or connect via Azure Portal:"
echo "     Portal > Virtual Machines > vm-lab-dev-eus-001 > Connect > Bastion"
echo ""
echo "  3. To destroy all resources when done:"
echo "     az group delete --name ${RESOURCE_GROUP} --yes --no-wait"
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/deploy.sh`

- [ ] **Step 3: Commit**

```bash
git add scripts/deploy.sh
git commit -m "feat: add deployment script with pre-flight checks"
```

---

### Task 10: Architecture Documentation

**Files:**
- Create: `docs/architecture.md`

- [ ] **Step 1: Create the architecture documentation**

```markdown
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
    │  │              rg-lab-dev-eus-001 (East US)                 │  │
    │  │                                                           │  │
    │  │  ┌─────────────────────────────────────────────────────┐  │  │
    │  │  │          vnet-lab-dev-eus-001 (10.0.0.0/16)         │  │  │
    │  │  │                                                     │  │  │
    │  │  │  ┌──────────────────┐  ┌─────────────────────────┐  │  │  │
    │  │  │  │ AzureBastionSnet │  │   snet-vms-dev-eus-001  │  │  │  │
    │  │  │  │   10.0.0.0/26    │  │      10.0.1.0/24        │  │  │  │
    │  │  │  │  ┌────────────┐  │  │  ┌───────────────────┐  │  │  │  │
    │  │  │  │  │  Bastion    │──│──│─▶│  vm-lab-dev-eus   │  │  │  │  │
    │  │  │  │  │  (Basic)    │  │  │  │  Ubuntu 22.04     │  │  │  │  │
    │  │  │  │  └────────────┘  │  │  │  B1s / SSH key     │  │  │  │  │
    │  │  │  └──────────────────┘  │  └───────────────────┘  │  │  │  │
    │  │  │                        │  nsg-vms: Bastion→22    │  │  │  │
    │  │  │                        └─────────────────────────┘  │  │  │
    │  │  │  ┌─────────────────────────────┐                    │  │  │
    │  │  │  │  snet-services-dev-eus-001  │                    │  │  │
    │  │  │  │       10.0.2.0/24           │                    │  │  │
    │  │  │  │  nsg-services: VNet only    │                    │  │  │
    │  │  │  └─────────────────────────────┘                    │  │  │
    │  │  └─────────────────────────────────────────────────────┘  │  │
    │  │                                                           │  │
    │  │  ┌──────────────────┐  ┌──────────────────────────────┐   │  │
    │  │  │ stlabdeveus001   │  │ law-lab-dev-eus-001          │   │  │
    │  │  │ StorageV2 / LRS  │  │ Log Analytics (30d)          │   │  │
    │  │  │ Boot diagnostics │  │ Azure Monitor Agent          │   │  │
    │  │  └──────────────────┘  └──────────────────────────────┘   │  │
    │  └───────────────────────────────────────────────────────────┘  │
    │                                                                 │
    │  RBAC: Contributor │ Reader │ VM Contributor                    │
    └─────────────────────────────────────────────────────────────────┘

## Component Details

### Networking Layer

**VNet (vnet-lab-dev-eus-001):** Single virtual network with /16 address space providing
network isolation. Three subnets separate concerns: Bastion access, VM workloads, and
backend services.

**NSGs:** Explicit deny-all rules with specific allow exceptions. The VMs NSG only allows
SSH from the Bastion subnet. The Services NSG allows intra-VNet traffic only.

**Azure Bastion (bas-lab-dev-eus-001):** Provides browser-based SSH access to VMs without
exposing public IPs. Basic SKU keeps costs low while covering exam topics.

### Compute Layer

**Linux VM (vm-lab-dev-eus-001):** Ubuntu 22.04 LTS on B1s (free-tier eligible). SSH key
authentication only — no passwords. Azure Monitor Agent extension installed for monitoring.

### Management Layer

**Storage Account (stlabdeveus001):** Standard LRS with a blob container for exercises.
Used for VM boot diagnostics. TLS 1.2 enforced, public blob access disabled.

**Log Analytics (law-lab-dev-eus-001):** Centralized log collection with 30-day retention
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
| `eus`        | East US     |
| `001`        | Instance    |

Exception: Storage accounts don't allow hyphens → `stlabdeveus001`

## Cost Estimate

| Resource        | SKU/Tier          | Estimated Monthly Cost |
|-----------------|-------------------|----------------------|
| VM (B1s)        | Free tier eligible| ~$0 (or ~$7.59)     |
| Bastion Basic   | Basic             | ~$140/mo while active|
| Storage (LRS)   | Standard          | ~$0.50               |
| Log Analytics   | 30d free tier     | ~$0                  |
| Public IP       | Standard (static) | ~$3.65               |
| **Total**       |                   | **~$4-$152/mo**      |

> **Cost tip:** Bastion is the main cost driver. Delete it when not in use and redeploy
> when needed. Alternatively, remove the Bastion module and use SSH with a public IP + NSG
> for a near-free lab.

## Cleanup

Delete everything with one command:

    az group delete --name rg-lab-dev-eus-001 --yes --no-wait
```

- [ ] **Step 2: Commit**

```bash
git add docs/architecture.md
git commit -m "docs: add architecture guide with AZ-104 exam domain mapping"
```

---

### Task 11: Final Validation

- [ ] **Step 1: Validate all Bicep files compile**

Run:
```bash
az bicep build --file main.bicep 2>&1
echo "Exit code: $?"
```
Expected: Exit code 0, no errors.

- [ ] **Step 2: Run what-if deployment (dry run)**

Run:
```bash
az deployment group what-if \
  --resource-group rg-lab-dev-eus-001 \
  --template-file main.bicep \
  --parameters main.bicepparam
```
Expected: Shows list of resources that would be created (all green "+").

- [ ] **Step 3: Final commit with all files verified**

```bash
git add -A
git commit -m "chore: verify all Bicep modules compile and what-if passes"
```
