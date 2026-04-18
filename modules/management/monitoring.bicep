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
