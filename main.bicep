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

@description('Connect to VM via: az network bastion ssh --name <bastionName> --resource-group <resourceGroupName> --target-resource-id <vm-id> --auth-type ssh-key --username azureadmin --ssh-key <path-to-private-key>')
output connectionInstructions string = 'Use Azure Bastion to connect: Portal > VM > Connect > Bastion'
