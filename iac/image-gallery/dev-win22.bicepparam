using './main.bicep'

param environment = 'dev'
param projectName = 'imagebuilder'
param location = 'australiaeast'
param galleryName = 'acg${environment}01'
param imageDefinitionName = 'gi-${environment}01-acg-win22'
param publisher = 'MicrosoftWindowsServer'
param offer = 'WindowsServer'
param sku = '222-Datacenter-gen2'
param osType = 'Windows'
param osState = 'Generalized'
param tags = {
  environment: environment
  project: projectName
}

