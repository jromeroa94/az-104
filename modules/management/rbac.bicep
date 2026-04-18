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
