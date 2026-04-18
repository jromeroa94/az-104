// main.bicepparam
// Parameter values for the AZ-104 Lab Landing Zone
// Update sshPublicKey with your actual SSH public key before deploying

using './main.bicep'

param location = 'canadacentral'
param environment = 'dev'
param workloadName = 'lab'
param regionAbbreviation = 'cac'
param storageAccountName = 'stlabdevcac001'

// REQUIRED: Replace with your SSH public key
// Generate one with: ssh-keygen -t ed25519 -C "az104-lab"
param sshPublicKey = readEnvironmentVariable('AZ104_SSH_PUBLIC_KEY', '')

// OPTIONAL: Set principal IDs for RBAC assignments
// Get your principal ID with: az ad signed-in-user show --query id -o tsv
param contributorPrincipalId = readEnvironmentVariable('AZ104_CONTRIBUTOR_PRINCIPAL_ID', '')
param readerPrincipalId = readEnvironmentVariable('AZ104_READER_PRINCIPAL_ID', '')
param vmContributorPrincipalId = readEnvironmentVariable('AZ104_VM_CONTRIBUTOR_PRINCIPAL_ID', '')
