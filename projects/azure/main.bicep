@description('Azure region')
param location string = resourceGroup().location
@description('Unique deployment label (letters/numbers/dashes)')
param prefix string = 'portfolio-lab'
@description('Administrator username; password is prompted securely')
param adminUsername string = 'labadmin'
@secure()
param adminPassword string
@description('Windows Server 2022 Azure Marketplace image')
param vmSize string = 'Standard_B2s'
var networkName = '${prefix}-vnet'
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: networkName
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.52.0.0/16'] }
    subnets: [{ name: 'workload'; properties: { addressPrefix: '10.52.1.0/24' } }]
  }
}
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${prefix}-nsg'
  location: location
  properties: { securityRules: [{ name: 'DenyInternetInbound'; properties: { priority: 100; direction: 'Inbound'; access: 'Deny'; protocol: '*'; sourcePortRange: '*'; destinationPortRange: '*'; sourceAddressPrefix: 'Internet'; destinationAddressPrefix: '*' } }] }
}
resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${prefix}-nic'
  location: location
  properties: { networkSecurityGroup: { id: nsg.id }; ipConfigurations: [{ name: 'ipconfig'; properties: { primary: true; privateIPAllocationMethod: 'Dynamic'; subnet: { id: vnet.properties.subnets[0].id } } }] }
}
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: '${prefix}-vm'
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: { computerName: 'lab-win'; adminUsername: adminUsername; adminPassword: adminPassword; windowsConfiguration: { provisionVMAgent: true; enableAutomaticUpdates: true } }
    storageProfile: { imageReference: { publisher: 'MicrosoftWindowsServer'; offer: 'WindowsServer'; sku: '2022-datacenter-azure-edition'; version: 'latest' }; osDisk: { createOption: 'FromImage'; managedDisk: { storageAccountType: 'Standard_LRS' } } }
    networkProfile: { networkInterfaces: [{ id: nic.id }] }
    diagnosticsProfile: { bootDiagnostics: { enabled: true } }
  }
}
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${prefix}-logs'
  location: location
  properties: { sku: { name: 'PerGB2018' }; retentionInDays: 30 }
}
output vmName string = vm.name
output vmPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output workspaceId string = workspace.id
