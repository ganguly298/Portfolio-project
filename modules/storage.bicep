// ============================================================
// storage.bicep — Storage Account
// Hosts: tables (DB), deployment-package container (Flex Consumption
// app package), and the $web container (static frontend).
// Runtime access is via managed identity; no keys are emitted.
// ============================================================

@description('Azure region')
param location string

@description('Storage account name (globally unique, lowercase, no hyphens)')
param storageAccountName string

@description('Name of the blob container Flex Consumption uses for the app package')
param deploymentContainerName string = 'deployment-package'

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
    allowSharedKeyAccess: true // kept on so the static-website CLI & seed script work
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-04-01' = {
  parent: storageAccount
  name: 'default'
}

resource deploymentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  parent: blobService
  name: deploymentContainerName
  properties: {
    publicAccess: 'None'
  }
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-04-01' = {
  parent: storageAccount
  name: 'default'
}

resource profileTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-04-01' = {
  parent: tableService
  name: 'profiles'
}

resource contactTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-04-01' = {
  parent: tableService
  name: 'contacts'
}

output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output staticWebsiteUrl string = storageAccount.properties.primaryEndpoints.web
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output tableEndpoint string = storageAccount.properties.primaryEndpoints.table
output deploymentContainerName string = deploymentContainer.name
output deploymentContainerUrl string = '${storageAccount.properties.primaryEndpoints.blob}${deploymentContainer.name}'
