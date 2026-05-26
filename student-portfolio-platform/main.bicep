// ============================================================
// main.bicep — Root orchestrator for Student Portfolio Platform
// Deploys: VNet, NSG, VM, Key Vault, Storage, Functions, Static Web App, Logic App, App Insights
// ============================================================

targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = 'centralindia'

@description('Your public IP address for RDP access (x.x.x.x)')
param myPublicIp string

@description('VM admin username')
param vmAdminUsername string = 'saurav'

@secure()
@description('VM admin password (stored in Key Vault)')
param vmAdminPassword string

@description('Project name prefix for resource naming')
param projectName string = 'portfolio'

// Unique suffix for globally unique names
var uniqueSuffix = uniqueString(resourceGroup().id)
var vnetName = '${projectName}-vnet'
var nsgName = '${projectName}-nsg-vm'
var vmName = '${projectName}-vm'
var kvName = '${projectName}-kv-${uniqueSuffix}'
var storageAccountName = '${projectName}st${uniqueSuffix}'
var functionAppName = '${projectName}-func-${uniqueSuffix}'
var staticWebAppName = '${projectName}-swa'
var logicAppName = '${projectName}-logic'
var appInsightsName = '${projectName}-insights'

// ─── The Wall (VNet + Subnets) ────────────────────────────────
module network 'modules/network.bicep' = {
  name: 'deploy-network'
  params: {
    location: location
    vnetName: vnetName
  }
}

// ─── The Security Guard (NSG) ─────────────────────────────────
module nsg 'modules/nsg.bicep' = {
  name: 'deploy-nsg'
  params: {
    location: location
    nsgName: nsgName
    myPublicIp: myPublicIp
    functionSubnetAddressPrefix: '10.0.2.0/24'
  }
}

// ─── The Camera (Application Insights) ────────────────────────
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
    vmAdminPassword: vmAdminPassword
  }
}

// ─── Storage Account (Functions backend) ──────────────────────
module storage 'modules/storage.bicep' = {
  name: 'deploy-storage'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

// ─── The Legacy System (Windows 11 VM) ────────────────────────
module vm 'modules/vm.bicep' = {
  name: 'deploy-vm'
  params: {
    location: location
    vmName: vmName
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    subnetId: network.outputs.vmSubnetId
    nsgId: nsg.outputs.nsgId
  }
}

// ─── The Modern API (Function App) ───────────────────────────
module functionApp 'modules/functionApp.bicep' = {
  name: 'deploy-functionapp'
  params: {
    location: location
    functionAppName: functionAppName
    storageAccountName: storage.outputs.storageAccountName
    storageAccountKey: storage.outputs.storageAccountKey
    appInsightsInstrumentationKey: monitoring.outputs.instrumentationKey
    functionSubnetId: network.outputs.functionSubnetId
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

// ─── The Frontend (Static Web App) ───────────────────────────
module staticWebApp 'modules/staticWebApp.bicep' = {
  name: 'deploy-staticwebapp'
  params: {
    location: location
    staticWebAppName: staticWebAppName
  }
}

// ─── The Notifier (Logic App) ────────────────────────────────
module logicApp 'modules/logicApp.bicep' = {
  name: 'deploy-logicapp'
  params: {
    location: location
    logicAppName: logicAppName
  }
}

// ─── Outputs ─────────────────────────────────────────────────
output vnetId string = network.outputs.vnetId
output vmPrivateIp string = vm.outputs.vmPrivateIp
output functionAppUrl string = functionApp.outputs.functionAppUrl
output staticWebAppUrl string = staticWebApp.outputs.staticWebAppUrl
output keyVaultUri string = keyVault.outputs.keyVaultUri
output logicAppEndpoint string = logicApp.outputs.logicAppEndpoint
