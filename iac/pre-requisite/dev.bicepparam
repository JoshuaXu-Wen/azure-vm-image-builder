using './main.bicep'

param location = 'australiaeast'
param environment = 'dev'
param projectName = 'imagebuilder'
param tags = {
  environment: environment
  project: projectName
}
param vNetName = 'vnet-${environment}'
param vnetAddressPrefix = '10.100.0.0/16'
param subnetAddressPrefix = '10.100.1.0/24'
param storageAccountName = 'stdimagebuilder01'

