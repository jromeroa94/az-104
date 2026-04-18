// modules/networking/nsg.bicep
// Defines Network Security Groups for VMs and Services subnets
// AZ-104 relevance: Configure and manage virtual networking (25-30%)

@description('Azure region for all resources')
param location string

@description('Base name prefix for resources')
@minLength(1)
@maxLength(67)
param namePrefix string

@description('Address prefix of the AzureBastionSubnet')
param bastionSubnetPrefix string = '10.0.0.0/26'

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
          sourceAddressPrefix: bastionSubnetPrefix
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
