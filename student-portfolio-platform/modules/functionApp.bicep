// ============================================================
// functionApp.bicep — The Modern API (Azure Functions)
// VNet integrated into Room B, reads secrets from Key Vault
// ============================================================

@description('Azure region')
param location string

@description('Function App name')
param functionAppName string

@description('Storage account name')
param storageAccountName string

@secure()
@description('Storage account key')
param storageAccountKey string

@description('App Insights instrumentation key')
param appInsightsInstrumentationKey string

@description('Subnet ID for Room B (subnet-functions)')
param functionSubnetId string

@description('Key Vault name for secret references')
param keyVaultName string

// Consumption plan (free tier)
resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${functionAppName}-plan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: false
  }
}

// Function App with VNet integration
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    virtualNetworkSubnetId: functionSubnetId
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'DB_HOST'
          value: '10.0.1.4' // VM private IP (first available in subnet-vm)
        }
        {
          name: 'DB_PORT'
          value: '5432'
        }
        {
          name: 'DB_USER'
          value: 'saurav'
        }
        {
          name: 'DB_PASSWORD'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=db-password)'
        }
        {
          name: 'DB_NAME'
          value: 'portfolio'
        }
      ]
      vnetRouteAllEnabled: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output functionAppPrincipalId string = functionApp.identity.principalId
