// ============================================================
// keyVault.bicep — Holds the application secret.
// (No storage connection string secret — Flex Consumption uses
// managed identity for both runtime AzureWebJobsStorage and table I/O.)
// ============================================================

@description('Azure region')
param location string

@description('Key Vault name (must be globally unique, 3-24 chars)')
param kvName string

@secure()
@description('App secret to store in Key Vault')
param appSecret string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enabledForTemplateDeployment: true
    softDeleteRetentionInDays: 7
  }
}

resource appSecretEntry 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'app-secret'
  properties: {
    value: appSecret
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output appSecretName string = appSecretEntry.name
