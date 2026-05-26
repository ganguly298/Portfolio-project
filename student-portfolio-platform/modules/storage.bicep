// ============================================================
// storage.bicep — Storage Account (required by Azure Functions)
// ============================================================

@description('Azure region')
param location string

@description('Storage account name (globally unique, lowercase, no hyphens)')
param storageAccountName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

output storageAccountName string = storageAccount.name
output storageAccountKey string = storageAccount.listKeys().keys[0].value
