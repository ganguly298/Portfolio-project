// ============================================================
// staticWebApp.bicep — The Frontend (Static Web App, Free tier)
// ============================================================

@description('Azure region')
param location string

@description('Static Web App name')
param staticWebAppName string

resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = {
  name: staticWebAppName
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {}
}

output staticWebAppUrl string = 'https://${staticWebApp.properties.defaultHostname}'
output staticWebAppId string = staticWebApp.id
