param location string = resourceGroup().location

param environment string = 'dev'
param projectName string = 'imagebuilder'
param tags object = {
  environment: environment
  project: projectName
}

@description('image builder identity name')
param identityName string = 'imageBuilderIdentity'
@description('builder VM identity name')
param vmIdentityName string = 'vmBuilderIdentity'

@description('base image details')
param publisher string = 'RedHat'
param offer string = 'RHEL'
param sku string = '9-gen2'
param version string = 'latest'
param vmSize string = 'Standard_D2s_v6'

@description('subnet ID for VM used during image build')
param subnetVmId string
@description('subnet ID for ACI used during image build')
param subnetAciId string

@description('staging resource group name')
param stagingResourceGroupName string = 'rg-${environment}-rhelstaging-01'
@description('gallery image ID')
param galleryImageId string


param storageAccountName string = 'stdimagebuilder01'
param customScriptName string = 'aap_request.py'
param sshPublicKey string = 'id_ed25519.pub'
param imageTemplateName string = 'rhel9-gen2-image-template'
param replicationRegions array = [
  'newzealandnorth'
]

// AAP details
param aapServer string = 'https://aap.example.com'
param workflowTemplateId string = '36'
@secure()
param aapToken string



var saFqdn = '${storageAccountName}.blob.${az.environment().suffixes.storage}'
var tagFromInput = loadYamlContent('../../tagsFile.yaml')
var resourceTags = union(tags, tagFromInput)


resource uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-05-31-preview' existing = {
  name: identityName
}

resource vmUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-05-31-preview' existing = {
  name: vmIdentityName
}

resource stagingResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: stagingResourceGroupName
  scope: subscription()
}

// Image Template
resource imageTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2024-02-01' = {
  name: imageTemplateName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uai.id}': {}
    }
  }
  properties: {
    source: {
      type: 'PlatformImage'
      publisher: publisher
      offer: offer
      sku: sku
      version: version
    }
    customize: [
      {
        name: 'DownloadScripts'
        type: 'Shell'
        inline: [
          'response=$(curl "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F" -H Metadata:true -s)'
          'access_token=$(echo $response | python3 -c "import sys, json; print (json.load(sys.stdin).access_token)")'
          'echo "Access token using a User-Assigned Managed Identity."'
          'headers="Authorization: Bearer $token"'
          'wget --header="$headers" --header="x-ms-version: 2024-02-04" "https://${saFqdn}/scripts/${customScriptName}" -O "/tmp/aap_request.py"'
          'wget --header="$headers" --header="x-ms-version: 2024-02-04" "https://${saFqdn}/files/${sshPublicKey}" -O "/tmp/ssh_key"'
        ]
      }
      {
        name: 'kick start image build'
        type: 'Shell'
        inline: [
        'sudo mkdir -p /root/.ssh'
        'sudo mv -f /tmp/ssh_key /root/.ssh/authorized_keys'
        'serverName=$(hostname)'
        'serverIP=$(hostname -I)'
        'echo "tags: ${resourceTags}"'
        'python3 /tmp/aap_request.py --aap-server "${aapServer}" --template-id "${workflowTemplateId}" --aap-token "${aapToken}" --server-name "$serverName" --server-ip "$serverIP" --vm-tags "${resourceTags}" --operation "image-build"'
        ]
      }
      {
        name: 'Cleanup'
        type: 'Shell'
        inline: [
          'rm -rf /tmp/aap_request.py'
        ]
      }
    ]
    distribute: [
      {
        type: 'SharedImage'
        galleryImageId: galleryImageId
        versioning: {
          scheme: 'Latest'
        }
        targetRegions: [
          for replicationRegion in replicationRegions: {
            name: replicationRegion
            replicaCount: 1
            storageAccountType: 'Standard_LRS'
          }
        ]
        runOutputName: 'azure-rhel-custom-image'
      }
    ]
    buildTimeoutInMinutes: 120
    vmProfile: {
      vmSize: vmSize
      osDiskSizeGB: 128
      vnetConfig: {
        subnetId: subnetVmId
        containerInstanceSubnetId: subnetAciId
      }
      userAssignedIdentities: [
        vmUai.id
      ]
    }
    stagingResourceGroup: stagingResourceGroup.id
    errorHandling: {
      onCustomizerError: 'abort'
    }
    optimize: {
      vmBoot: {
        state: 'Enabled'
      }
    }
    autoRun: {
      state: 'Enabled'
    }
  }
}

output imageTemplateId string = imageTemplate.id
