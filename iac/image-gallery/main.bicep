
param environment string = 'dev'
param projectName string = 'imagebuilder'
param location string = resourceGroup().location
param galleryName string = 'myImageGallery'
param imageDefinitionName string = 'myImageDefinition'
@description('Base image publisher for the image definition')
param publisher string = 'MicrosoftWindowsServer'
@description('Base image offer for the image definition')
param offer string = 'WindowsServer'
@description('Base image sku for the image definition')
param sku string = '222-Datacenter-gen2'
@description('OS type of the image definition')
param osType string = 'Windows'

@description('OS state of the image definition')
@allowed(['Generalized', 'Specialized'])
param osState string = 'Generalized'

@description('Tags for the image definition')
param tags object = {
  environment: environment
  project: projectName
}

// Create Shared Image Gallery
resource gallery 'Microsoft.Compute/galleries@2025-03-03' = {
  name: galleryName
  location: location
  tags: tags
  properties: {
    description: 'Shared Image Gallery for VM images'
  }
}

// Create Image Definition
resource imageDefinition 'Microsoft.Compute/galleries/images@2025-03-03' = {
  parent: gallery
  name: imageDefinitionName
  location: location
  tags: tags
  properties: {
    osType: osType
    osState: osState
    identifier: {
      publisher: publisher
      offer: offer
      sku: sku
    }
    recommended: {
      vCPUs: {
        min: 2
        max: 8
      }
      memory: {
        min: 4
        max: 256
      }
    }
    description: 'Custom ${osType} image definition'
    architecture: 'x64'
    hyperVGeneration: 'V2'
  }
}

output galleryId string = gallery.id
output imageDefinitionId string = imageDefinition.id
