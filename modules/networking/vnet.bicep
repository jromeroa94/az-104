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
