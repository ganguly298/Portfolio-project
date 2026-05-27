// ============================================================
// storage.bicep — Storage Account
// Functions backend + Azure Table Storage as lightweight DB
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

// Table service for lightweight NoSQL data
resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-04-01' = {
  parent: storageAccount
  name: 'default'
}

// Profile table — stores portfolio data
resource profileTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-04-01' = {
  parent: tableService
  name: 'profiles'
}

// Contact table — stores contact form submissions
resource contactTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-04-01' = {
  parent: tableService
  name: 'contacts'
}

output storageAccountName string = storageAccount.name
output storageAccountKey string = storageAccount.listKeys().keys[0].value
output storageConnectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
output staticWebsiteUrl string = storageAccount.properties.primaryEndpoints.web
