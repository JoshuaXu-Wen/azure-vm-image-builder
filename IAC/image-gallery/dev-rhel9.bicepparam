using './main.bicep'

param environment = 'dev'
param projectName = 'imagebuilder'
param location = 'australiaeast'
param galleryName = 'acg${environment}01'
param imageDefinitionName = 'gi-${environment}01-acg-rhel9'
param publisher = 'RedHat'
param offer = 'RHEL'
param sku = '9-lvm-gen2'
param osType = 'Linux'
param osState = 'Generalized'
param tags = {
  environment: environment
  project: projectName
}

