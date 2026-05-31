// ============================================================
// kvRoleAssignment.bicep
// Grants the Function App's managed identity "Key Vault Secrets User"
// so @Microsoft.KeyVault(...) references resolve at runtime.
// ============================================================

@description('Key Vault name')
param keyVaultName string

@description('Principal ID of the Function App managed identity')
param principalId string

// Built-in role: Key Vault Secrets User
var secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, principalId, secretsUserRoleId)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsUserRoleId)
  }
}
