// ============================================================
// keyVault.bicep — The Safe (Key Vault for secrets management)
// Demonstrates storing and retrieving secrets securely
// ============================================================

@description('Azure region')
param location string

@description('Key Vault name (globally unique)')
param kvName string

@secure()
@description('Application secret to store')
param appSecret string

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

// Store the app secret
resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'app-secret'
  properties: {
    value: appSecret
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output secretUri string = secret.properties.secretUri
