// ============================================================
// functionApp.bicep — The API (Azure Functions, Flex Consumption)
// Linux, Node 20, identity-based AzureWebJobsStorage,
// app package pulled from a blob container via system-assigned MI.
// No content file share, no storage keys anywhere.
// ============================================================

@description('Azure region')
param location string

@description('Function App name')
param functionAppName string

@description('Storage account name (used for table I/O and AzureWebJobsStorage)')
param storageAccountName string

@description('Blob container URL Flex Consumption pulls the app package from')
param deploymentStorageContainerUrl string

@description('App Insights instrumentation key')
param appInsightsInstrumentationKey string

@description('Key Vault name for app-secret KV reference')
param keyVaultName string

@description('Logic App callback URL for contact notifications')
param logicAppCallbackUrl string = ''

@description('Allowed CORS origins for the Function App')
param allowedOrigins array = [
  'https://portal.azure.com'
  'http://localhost:3000'
]

// Flex Consumption plan (FC1) — Linux only
resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${functionAppName}-plan'
  location: location
  kind: 'functionapp'
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true
  }
}

// Function App — Flex Consumption, Linux, MI-based storage
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: deploymentStorageContainerUrl
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'node'
        version: '20'
      }
    }
    siteConfig: {
      appSettings: [
        // Identity-based AzureWebJobsStorage — no connection string, no key.
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
        {
          name: 'APP_SECRET'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=app-secret)'
        }
        {
          name: 'LOGIC_APP_CALLBACK_URL'
          value: logicAppCallbackUrl
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: allowedOrigins
      }
    }
  }
}

output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output functionAppName string = functionApp.name
output functionAppPrincipalId string = functionApp.identity.principalId
