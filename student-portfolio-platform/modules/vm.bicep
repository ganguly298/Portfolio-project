// ============================================================
// vm.bicep — The Legacy System (Windows 11 Pro 25H2 VM)
// No public IP — only accessible via VNet (Room A)
// Auto-shutdown at 23:00 IST to save credits
// ============================================================

@description('Azure region')
param location string

@description('VM name')
param vmName string

@description('Admin username')
param adminUsername string

@secure()
@description('Admin password')
param adminPassword string

@description('Subnet ID for Room A (subnet-vm)')
param subnetId string

@description('NSG ID for the Security Guard')
param nsgId string

// NIC — Private IP only, no public IP, NSG attached
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgId
    }
  }
}

// Windows 11 Pro 25H2 VM
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s_v2'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-25h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 128
      }
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

// Auto-shutdown at 23:00 IST (17:30 UTC)
resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '2300'
    }
    timeZoneId: 'India Standard Time'
    targetResourceId: vm.id
    notificationSettings: {
      status: 'Disabled'
    }
  }
}

output vmPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmId string = vm.id
