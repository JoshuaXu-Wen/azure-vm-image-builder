param location string = resourceGroup().location
param imageIdentityName string = 'imageBuilderIdentity'
param vmIdentityName string = 'vmBuilderIdentity'
param tags object

// Managed Identity for Image Builder
resource ImageManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-05-31-preview' = {
  name: imageIdentityName
  location: location
  tags: tags
}

// Managed Identity for Builder VM
resource VmManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-05-31-preview' = {
  name: vmIdentityName
  location: location
  tags: tags
}

output imageIdentityPrincipalId string = ImageManagedIdentity.properties.principalId
output imageIdentityClientId string = ImageManagedIdentity.properties.clientId
output vmIdentityPrincipalId string = VmManagedIdentity.properties.principalId
output vmIdentityClientId string = VmManagedIdentity.properties.clientId
