// ============================================================
// main.bicep — Root orchestrator for Student Portfolio Platform
// Deploys: Storage, Key Vault, Function App (Y1), Logic App, App Insights
// Serverless & near-zero cost on Azure for Students
// ============================================================

targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = 'centralindia'

@description('Project name prefix for resource naming')
param projectName string = 'portfolio'

@secure()
@description('A secret value to store in Key Vault (demonstrates secrets management)')
param appSecret string

// Unique suffix for globally unique names
var uniqueSuffix = uniqueString(resourceGroup().id)
var kvName = '${projectName}kv${uniqueSuffix}'
var storageAccountName = '${projectName}st${uniqueSuffix}'
var functionAppName = '${projectName}-func-${uniqueSuffix}'
var logicAppName = '${projectName}-logic-${uniqueSuffix}'
var appInsightsName = '${projectName}-insights'

// ─── Monitoring (Application Insights) ────────────────────────
module monitoring 'modules/monitoring.bicep' = {
  name: 'deploy-monitoring'
  params: {
    location: location
    appInsightsName: appInsightsName
  }
}

// ─── The Safe (Key Vault) ─────────────────────────────────────
module keyVault 'modules/keyVault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    location: location
    kvName: kvName
    appSecret: appSecret
  }
}

// ─── Storage Account (Functions backend + Table Storage as DB) ─
module storage 'modules/storage.bicep' = {
  name: 'deploy-storage'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

// ─── The Notifier (Logic App — Consumption) ──────────────────
// Deploy this first so we can pass its callback URL to the Function App
module logicApp 'modules/logicApp.bicep' = {
  name: 'deploy-logicapp'
  params: {
    location: location
    logicAppName: logicAppName
  }
}

// ─── The API (Function App — Y1 Consumption) ─────────────────
module functionApp 'modules/functionApp.bicep' = {
  name: 'deploy-functionapp'
  params: {
    location: location
    functionAppName: functionAppName
    storageAccountName: storage.outputs.storageAccountName
    storageAccountKey: storage.outputs.storageAccountKey
    appInsightsInstrumentationKey: monitoring.outputs.instrumentationKey
    keyVaultName: keyVault.outputs.keyVaultName
    storageConnectionString: storage.outputs.storageConnectionString
    logicAppCallbackUrl: logicApp.outputs.logicAppCallbackUrl
  }
}

// ─── Outputs ─────────────────────────────────────────────────
output functionAppUrl string = functionApp.outputs.functionAppUrl
output frontendUrl string = storage.outputs.staticWebsiteUrl
output keyVaultUri string = keyVault.outputs.keyVaultUri
output logicAppEndpoint string = logicApp.outputs.logicAppEndpoint
output storageAccountName string = storage.outputs.storageAccountName
