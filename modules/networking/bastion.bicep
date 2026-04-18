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
