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
