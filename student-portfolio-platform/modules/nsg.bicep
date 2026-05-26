// ============================================================
// nsg.bicep — The Security Guard (NSG on Room A)
// Rules: Allow RDP from YOUR IP + Allow DB from Room B + Deny all else
// ============================================================

@description('Azure region')
param location string

@description('NSG name')
param nsgName string

@description('Your public IP for RDP access')
param myPublicIp string

@description('Function subnet address prefix (Room B)')
param functionSubnetAddressPrefix string

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        // Let YOU in via RDP for initial setup
        name: 'AllowRDP-FromMyIP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '${myPublicIp}/32'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        // The Handshake — Function App (Room B) can reach PostgreSQL
        name: 'AllowPostgres-FromFunctionSubnet'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: functionSubnetAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '5432'
        }
      }
      {
        // Deny everything else
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

output nsgId string = nsg.id
