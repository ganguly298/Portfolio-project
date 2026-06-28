// ============================================================
// vmSecret.bicep — Writes a single secret into an EXISTING Key
// Vault. Used by vm.bicep as a cross-resource-group sub-module
// so the VM (in a per-user RG) can store its password in the
// shared portfolio Key Vault.
// ============================================================

@description('Existing Key Vault name to write the secret into.')
param kvName string

@description('Secret name. Convention: pass-<vmName>.')
param secretName string

@secure()
@description('Secret value (the generated VM admin password).')
param secretValue string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: kvName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: secretName
  properties: {
    value: secretValue
  }
}

output kvUri string = kv.properties.vaultUri
output secretName string = secret.name
