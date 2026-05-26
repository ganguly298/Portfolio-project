// ============================================================
// monitoring.bicep — The Camera (Application Insights)
// ============================================================

@description('Azure region')
param location string

@description('App Insights resource name')
param appInsightsName string

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 30
    IngestionMode: 'ApplicationInsights'
  }
}

output instrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsId string = appInsights.id
