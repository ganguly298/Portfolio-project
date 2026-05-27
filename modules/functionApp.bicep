// ============================================================
// functionApp.bicep — The API (Azure Functions, Y1 Consumption)
// No VNet integration — uses Table Storage as database
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

@description('Key Vault name for secret references')
param keyVaultName string

@description('Storage connection string for Table Storage access')
param storageConnectionString string

@description('Allowed CORS origins for the Function App')
param allowedOrigins array = [
  'https://portal.azure.com'
  'http://localhost:3000'
]

// Consumption plan (Y1 — free tier, 1M executions/month)
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

// Function App — public endpoint, no VNet
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
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
          name: 'TABLE_STORAGE_CONNECTION'
          value: storageConnectionString
        }
        {
          name: 'APP_SECRET'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=app-secret)'
        }
        // Enable remote build during zip deploy so `npm install` runs and
        // node_modules (e.g. @azure/data-tables) end up on the function host.
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: allowedOrigins
      }
    }
    httpsOnly: true
  }
}

output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output functionAppPrincipalId string = functionApp.identity.principalId
