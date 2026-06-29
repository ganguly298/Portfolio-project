// ============================================================
// vm.bicep — Self-contained ephemeral demo VM.
//
// Deployed by the Function App into a PER-USER resource group.
// Each VM gets its own VNet so deleting the RG cleans up
// everything. Public IP is optional — when disabled, connect
// via Azure Bastion from the portal. The admin password is
// supplied by the caller (the signed-in user via the API) and
// is stored in the existing portfolio Key Vault via
// vmSecret.bicep.
// ============================================================

@description('Short suffix used to name all VM resources (typically a sanitised user-supplied VM label).')
@minLength(2)
@maxLength(12)
param name string

@description('Azure region for the VM and its network resources.')
@allowed([
  'malaysiawest'
  'southeastasia'
  'centralindia'
  'uaenorth'
  'austriaeast'
])
param location string

@description('Local admin username for the VM.')
param username string = 'demouser'

@description('VM size. Default kept small to control cost.')
param vmSize string = 'Standard_B2s_v2'

@description('If true, create a public IP and an NSG allowing inbound RDP from the Internet.')
param createPublicIp bool = false

@secure()
@description('Admin password for the VM. Supplied by the signed-in user.')
param adminPassword string

@description('Existing Key Vault name where the admin password will be stored.')
param kvName string

@description('Resource group containing the existing Key Vault.')
param kvResourceGroup string

var suffix = uniqueString(resourceGroup().id, name)
var vmName = 'vm-${name}'
var nicName = 'nic-${name}-${suffix}'
var vnetName = 'vnet-${name}-${suffix}'
var pipName = 'pip-${name}-${suffix}'
var nsgName = 'nsg-${name}-${suffix}'
var subnetName = 'default'
var secretName = 'pass-${vmName}-${suffix}'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.0.0.0/16' ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2023-09-01' = if (createPublicIp) {
  name: pipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = if (createPublicIp) {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  properties: {
    networkSecurityGroup: createPublicIp ? { id: nsg.id } : null
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: createPublicIp ? { id: pip.id } : null
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'microsoftwindowsdesktop'
        offer: 'windows-11'
        sku: 'win11-25h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        deleteOption: 'Delete'
      }
    }
    osProfile: {
      computerName: take(name, 15)
      adminUsername: username
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

module storePassword './vmSecret.bicep' = {
  name: 'kv-secret-${name}'
  scope: resourceGroup(kvResourceGroup)
  params: {
    kvName: kvName
    secretName: secretName
    secretValue: adminPassword
  }
}

output vmName string = vmName
output adminUsername string = username
output publicIp string = createPublicIp ? pip!.properties.ipAddress : ''
#disable-next-line outputs-should-not-contain-secrets
output kvSecretName string = secretName
#disable-next-line outputs-should-not-contain-secrets
output kvSecretReference string = '${storePassword.outputs.kvUri}secrets/${secretName}'
