// ============================================================
// main.bicep — Root orchestrator for Student Portfolio Platform
// Flex Consumption Functions + Table Storage + Key Vault + Logic App + App Insights
// No storage keys leave the storage account — runtime is identity-only.
// ============================================================

targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = 'centralindia'

@description('Project name prefix for resource naming')
param projectName string = 'portfolio'

@secure()
@description('A secret value to store in Key Vault (demonstrates secrets management)')
param appSecret string

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

// ─── Storage Account (tables + deployment container + $web) ──
module storage 'modules/storage.bicep' = {
  name: 'deploy-storage'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

// ─── The Notifier (Logic App — Consumption) ──────────────────
module logicApp 'modules/logicApp.bicep' = {
  name: 'deploy-logicapp'
  params: {
    location: location
    logicAppName: logicAppName
  }
}

// ─── The API (Function App — Flex Consumption, MI-based) ─────
module functionApp 'modules/functionApp.bicep' = {
  name: 'deploy-functionapp'
  params: {
    location: location
    functionAppName: functionAppName
    storageAccountName: storage.outputs.storageAccountName
    deploymentStorageContainerUrl: storage.outputs.deploymentContainerUrl
    appInsightsInstrumentationKey: monitoring.outputs.instrumentationKey
    keyVaultName: keyVault.outputs.keyVaultName
    logicAppCallbackUrl: logicApp.outputs.logicAppCallbackUrl
  }
}

// ─── RBAC: Function App MI → Storage data-plane roles ─────────
module storageRoleAssignment 'modules/storageRoleAssignment.bicep' = {
  name: 'deploy-storage-rbac'
  params: {
    storageAccountName: storage.outputs.storageAccountName
    principalId: functionApp.outputs.functionAppPrincipalId
  }
}

// ─── RBAC: Function App MI → Key Vault Secrets User ───────────
module kvRoleAssignment 'modules/kvRoleAssignment.bicep' = {
  name: 'deploy-kv-rbac'
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    principalId: functionApp.outputs.functionAppPrincipalId
  }
}

// ─── Outputs ─────────────────────────────────────────────────
output functionAppUrl string = functionApp.outputs.functionAppUrl
output functionAppName string = functionApp.outputs.functionAppName
output frontendUrl string = storage.outputs.staticWebsiteUrl
output keyVaultUri string = keyVault.outputs.keyVaultUri
output logicAppEndpoint string = logicApp.outputs.logicAppEndpoint
output storageAccountName string = storage.outputs.storageAccountName
output deploymentContainerName string = storage.outputs.deploymentContainerName
