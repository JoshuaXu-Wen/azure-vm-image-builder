targetScope = 'subscription'
param environment string = 'dev'
param projectName string = 'imagebuilder'
param location string = 'australiaeast'
param acgRgName string = 'rg-${environment}-imagegallery-01'
param imageBuilderRgName string = 'rg-${environment}-imagebuilder-01'
param rhelStagingRgName string = 'rg-${environment}-rhelstaging-01'
param winStagingRgName string = 'rg-${environment}-winstaging-01'

param tags object = {
  environment: environment
  project: projectName
}

// Resource Group for Image Builder and Image Gallery
resource imageBuilderRg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: imageBuilderRgName
  location: location
  tags: tags
}

// Resource Group for Image Gallery
resource acgRg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: acgRgName
  location: location
  tags: tags
}

// Resource Group for RHEL staging
resource rhelStagingRg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: rhelStagingRgName
  location: location
  tags: tags
}

// Resource Group for Windows staging
resource winStagingRg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: winStagingRgName
  location: location
  tags: tags
}

