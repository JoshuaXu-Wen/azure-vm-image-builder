metadata description = 'Main Bicep template that orchestrates deployment of infrastructure modules'

param location string = resourceGroup().location
param environment string = 'dev'
param projectName string
param tags object = {
  environment: environment
  project: projectName
}
// Network Module Parameters
param vNetName string = 'vnet-${environment}'
param vnetAddressPrefix string = '10.0.0.0/16'
param subnetAddressPrefix string = '10.0.1.0/24'
param vmSubnetAddressPrefix string = '10.0.2.0/24'
param aciSubnetAddressPrefix string = '10.0.3.0/24'

// Storage Module Parameters
param storageAccountName string

// Module: Virtual Network
module networkModule 'modules/vnet.bicep' = {
  name: 'networkDeployment'
  params: {
    location: location
    environment: environment
    vNetName: vNetName
    vnetAddressPrefix: vnetAddressPrefix
    subnetAddressPrefix: subnetAddressPrefix
    vmSubnetAddressPrefix: vmSubnetAddressPrefix
    aciSubnetAddressPrefix: aciSubnetAddressPrefix
    tags: tags
  }
}

// Module: Storage Account
module storageModule 'modules/storageAccount.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    environment: environment
    storageAccountName: storageAccountName
    subnetId: networkModule.outputs.subnetId
    privateDnsZoneId: privateDnsZoneModule.outputs.privateDnsZoneId
    tags: tags
  }
}

// Module: Private DNS Zone
module privateDnsZoneModule 'modules/privateDnsZone.bicep' = {
  name: 'privateDnsZoneDeployment'
  params: {
    environment: environment
    vnetId: networkModule.outputs.vnetId
    tags: tags
  }
}

// Outputs
output vnetId string = networkModule.outputs.vnetId
output subnetId string = networkModule.outputs.subnetId
output storageAccountId string = storageModule.outputs.storageAccountId
