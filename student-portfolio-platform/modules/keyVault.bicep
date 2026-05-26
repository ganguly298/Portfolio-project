// ============================================================
// keyVault.bicep — The Safe (Key Vault for secrets)
// Stores VM DB credentials for Function App to retrieve
// ============================================================

@description('Azure region')
param location string

@description('Key Vault name (globally unique)')
param kvName string

@secure()
@description('VM admin password to store as secret')
param vmAdminPassword string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
  }
}

// Store the DB password as a secret
resource dbPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'db-password'
  properties: {
    value: vmAdminPassword
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output dbPasswordSecretUri string = dbPasswordSecret.properties.secretUri
