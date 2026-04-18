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
