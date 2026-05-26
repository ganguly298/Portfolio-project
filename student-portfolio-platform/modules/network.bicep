// ============================================================
// network.bicep — The Wall (VNet + Room A + Room B)
// ============================================================

@description('Azure region')
param location string

@description('VNet name')
param vnetName string

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        // Room A — VM lives here (locked down)
        name: 'subnet-vm'
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        // Room B — Function App connects here (delegated)
        name: 'subnet-functions'
        properties: {
          addressPrefix: '10.0.2.0/24'
          delegations: [
            {
              name: 'delegation-functions'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vmSubnetId string = vnet.properties.subnets[0].id
output functionSubnetId string = vnet.properties.subnets[1].id
