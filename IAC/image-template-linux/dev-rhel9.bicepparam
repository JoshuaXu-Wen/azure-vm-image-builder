using './main.bicep'

param location = 'australiaeast'
param environment = 'dev'
param projectName = 'imagebuilder'
param tags = {
  environment: environment
  project: projectName
}
param identityName = 'imageBuilderIdentity'
param vmIdentityName = 'vmBuilderIdentity'
param publisher = 'RedHat'
param offer = 'RHEL'
param sku = '9-gen2'
param version = 'latest'
param vmSize = 'Standard_D2s_v6'
param subnetVmId = ''
param subnetAciId = ''
param stagingResourceGroupName = 'rg-${environment}-rhelstaging-01'
param galleryImageId = ''
param storageAccountName = 'stdimagebuilder01'
param customScriptName = 'aap_request.py'
param sshPublicKey = 'id_ed25519.pub'
param imageTemplateName = 'rhel9-gen2-image-template'
param replicationRegions = [
  'newzealandnorth'
]
param aapServer = 'https://aap.example.com'
param workflowTemplateId = '36'
param aapToken = ''

