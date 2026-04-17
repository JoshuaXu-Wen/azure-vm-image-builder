targetScope = 'resourceGroup'

param environment string = 'dev'
param projectName string = 'imagebuilder'
param tags object = {
  environment: environment
  project: projectName
}
// param azureImageBuilderRoleId string
param contributorRoleId string = 'b24988ac-6180-42a0-ab88-20f7382dd24' // Built-in Contributor role ID
param storageBlobDataReaderRoleId string = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Built-in Storage Blob Data Reader role ID
param managedIdentityOperationsRoleId string = 'f1a07417-d97a-45cb-824c-7a7467783830' // Managed Identity Operator role ID

param rhelStagingRgName string = 'rg-${environment}-rhelstaging-01'
param winStagingRgName string = 'rg-${environment}-winstaging-01'
// param imageBuilderRgName string = 'rg-${environment}-imagebuilder-01'
param acgRgName string = 'rg-${environment}-imagegallery-01'
param virtualNetworkName string = 'vnet-${environment}-01'


// Parameters for Identities module
param imageIdentityName string = 'imageBuilderIdentity'
param vmIdentityName string = 'vmBuilderIdentity'


var stagingResourceGroups = [
  rhelStagingRgName
  winStagingRgName
]


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup()
}

// Module: Identities
module identitiesModule 'modules/identities.bicep' = {
  name: 'identitiesDeployment'
  scope: resourceGroup()
  params: {
    imageIdentityName: imageIdentityName
    vmIdentityName: vmIdentityName
    tags: tags
  }
}

module customRoleModule 'modules/roles.bicep' = {
  name: 'customRoleDeployment'
  scope: subscription()
}

module imageBuilderRoleAssignmentsModule 'modules/roleAssignments.bicep' = {
  name: 'roleAssignments-imageBuilderDeployment'
  scope: resourceGroup(acgRgName)
  params: {
    principalId: identitiesModule.outputs.imageIdentityPrincipalId
    roleDefinitionID: customRoleModule.outputs.roleDefinitionId
  }
}

module blobDataReaderRoleAssignmentsModule 'modules/roleAssignments.bicep' = {
  name: 'roleAssignments-blobDataReaderDeployment'
  scope: resourceGroup()
  params: {
    principalId: identitiesModule.outputs.imageIdentityPrincipalId
    roleDefinitionID: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRoleId)
  }
}

// Role assignement for Image Builder Managed Identity to have Network Joinber role on virtual network
// if the virtual network is in a different resource group, the role assignment needs to be set in seperate assignments,
// otherwise, the scope is not valid as the virtual network is in a different resource group than the role assignment deployment
resource networkRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(virtualNetwork.name, resourceGroup().id)
  scope: virtualNetwork
  properties: {
    roleDefinitionId: customRoleModule.outputs.networkRoleDefinitionId
    principalId: identitiesModule.outputs.imageIdentityPrincipalId
  }
}

module managedIdentityOperatorRoleAssignmentsModule 'modules/roleAssignments.bicep' = {
  name: 'roleAssignments-managedIdentityOperatorDeployment'
  scope: resourceGroup()
  params: {
    principalId: identitiesModule.outputs.imageIdentityPrincipalId
    roleDefinitionID: resourceId('Microsoft.Authorization/roleDefinitions', managedIdentityOperationsRoleId)
  }
}

module ContributorRoleAssignmentsModule 'modules/roleAssignments.bicep' = [for rgName in stagingResourceGroups: {
  name: 'roleAssignments-contributorDeployment-${rgName}'
  scope: resourceGroup(rgName)
  params: {
    principalId: identitiesModule.outputs.imageIdentityPrincipalId
    roleDefinitionID: resourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
  }
}]

// Role assignment for Builder VM to have Storage Blob Data Reader role on image builder resource group
// used for the builder VM to download files and scripts during the image build process
module vmIdentityBlobDataReaderRoleAssignmentsModule 'modules/roleAssignments.bicep' = {
  name: 'roleAssignments-vmIdentity-blobDataReaderDeployment'
  scope: resourceGroup()
  params: {
    principalId: identitiesModule.outputs.vmIdentityPrincipalId
    roleDefinitionID: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRoleId)
  }
}
