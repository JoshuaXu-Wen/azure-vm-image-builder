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
param publisher string = 'MicrosoftWindowsServer'
param offer string = 'WindowsServer'
param sku string = '2022-Datacenter-g2'
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
param imageTemplateName string = 'rhel9-gen2-image-template'
param replicationRegions array = [
  'newzealandnorth'
]

// AAP details
param aapServer string = 'https://aap.example.com'
param workflowTemplateId string = '36'
@secure()
param aapToken string


param adminUsername string = 'imagebuilder'
@secure()
param adminPassword string

param customPowerShellScriptName string = 'post_provision.ps1'
param customPythonScriptName string = 'aap_request.py'
param customScheduleTaskScriptName string = 'schedule_task.ps1'


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
        name: 'Create Admin user'
        type: 'PowerShell'
        runElevated: true
        runAsSystem: true
        inline: [
          'New-LocalUser -Name "${adminUsername}" -Password (ConvertTo-SecureString "${adminPassword}" -AsPlainText -Force)'
          'Add-LocalGroupMember -Group "Administrators" -Member "${adminUsername}"'
          'Write-Host "Admin user ${adminUsername} created and added to Administrators group."'
          'Set-LocalUser -Name "${adminUsername}" -PasswordNeverExpires $true'
        ]
      }
      {
        name: 'Add Firewall rule for WinRM over HTTPS'
        type: 'PowerShell'
        runElevated: true
        runAsSystem: true
        inline: [
          'Write-Host "Configuring Firewall rule for WinRM over HTTPS..."'
          'New-NetFirewallRule -Name "Allow-WinRM-HTTPS" -DisplayName "Allow WinRM over HTTPS" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5986'
        ]
      }
      {
        name: 'DownloadScripts'
        type: 'PowerShell'
        runElevated: true
        runAsSystem: true
        inline: [
          'Write-Host "Creating script folder..."'
          'New-Item -Path "$env:SystemDrive:\\scripts" -ItemType Directory -Force'
          'response = Invoke-WebRequest "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F" -Headers @{Metadata="true"} -Method GET'
          'access_token = $response.access_token'
          '$headers = @{Authorization = "Bearer $access_token"; "x-ms-version" = "2024-02-04"}'
          '$customScriptFolder = "$env:SystemDrive:\\scripts"'
          'invoke-webrequest -H $headers -uri "https://${saFqdn}/scripts/${customPowerShellScriptName}" -OutFile "$customScriptFolder\\${customPowerShellScriptName}"'
          'invoke-webrequest -H $headers -uri "https://${saFqdn}/scripts/${customPythonScriptName}" -OutFile "$customScriptFolder\\${customPythonScriptName}"'
          'invoke-webrequest -H $headers -uri "https://${saFqdn}/files/${customScheduleTaskScriptName}" -OutFile "$customScriptFolder\\${customScheduleTaskScriptName}"'

          '$pythonInstallerPath = "$customScriptFolder\\python.exe"'
          'invoke-webrequest -H $headers -uri "https://${saFqdn}/files/python-3.13.13-amd64.exe" -OutFile $pythonInstallerPath'
          'invoke-webrequest -H $headers -uri "https://${saFqdn}/files/modules.zip" -OutFile "$customScriptFolder\\modules.zip"'

          'if (Test-Path $pythonInstallerPath) {'
          '  Write-Host "Python installer downloaded. Extracting modules..."'
          '  Expand-Archive -Path "$customScriptFolder\\modules.zip" -DestinationPath "$customScriptFolder\\modules" -Force'
          'Start-Process -FilePath $pythonInstallerPath -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1" -Wait -Verb RunAs'
        ]
      }
      {
        name: 'Install python modules requests'
        type: 'PowerShell'
        runElevated: true
        runAsSystem: true
        inline: [
          'if (Get-Command python -ErrorAction SilentlyContinue) {'
          '  Write-Host "Python is already installed."'
          '} else {'
          '  Write-Host "Python is not installed."'
          '}'
          '$pythonPath = (Get-Command python).Source'
          'Write-Host "Python executable path: $pythonPath"'
          '$modulesFolder = "$customScriptFolder\\modules"'
          'Get-ChildItem -Path $modulesFolder -Filter "*.whl" | Where-Object { $_.Name -notlike "requests-*.whl" } | ForEach-Object {'
          ' & $pythonPath -m pip install $_.FullName'
          '}'
          '$requestsModule = Get-ChildItem -Path $modulesFolder -Filter "requests-*.whl" | Select-Object -First 1'
          ' & $pythonPath -m pip install $requestsModule.FullName'
        ]
      }
    {
        name: 'Run python script to kick start image build in AAP'
        type: 'PowerShell'
        runElevated: true
        runAsSystem: true        
        inline: [
        'Set-Item -Path WSMan:\\location\\Service\\Auth\\Kerberos -Value $true'
        'Set-Item -Path WSMan:\\location\\Service\\Auth\\Negotiate -Value $true'
        'New-ItemProperty -Path HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System -Name "LocalAccountTokenFilterPolicy" -Value 1 -PropertyType DWord -Force'
        '$customScriptFolder = "$env:SystemDrive:\\scripts"'
        '$serverName = $env:COMPUTERNAME'
        '$serverIP = (Get-NetIPAddress -AddressFamily IPv4) | Where-Object { $_.IPAddress -ne "127.0.0.1" }).IPAddress'
        'Write-Host "Server Name: $serverName, Server IP: $serverIP"'
        'python3 $customScriptFolder\\${customPythonScriptName} --aap-server "${aapServer}" --template-id "${workflowTemplateId}" --aap-token "${aapToken}" --server-name "$serverName" --server-ip "$serverIP" --vm-tags "${resourceTags}" --operation "image-build"'
        ]
      }
      {
        name: 'Uninstall python'
        type: 'PowerShell'
        runElevated: true
        runAsSystem: true  
        inline: [
          '$pythonProduct = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "Python*" }'
          'if ($pythonProduct) {'
          '  Write-Host "Found Python installation at $pythonProduct.InstallLocation"'
          '  $pythonProduct.Uninstall()'
          '} else {'
          '  Write-Host "Python not found."'
          '}'
          'Remove-Item -Path "$customScriptFolder\\python.exe" -Force'
          'Remove-Item -Path "$customScriptFolder\\modules.zip" -Force'
          'Remove-Item -Path "$customScriptFolder\\modules" -Recurse -Force'
          'Write-Host "Python and related files have been removed."'
          'Set-ItemProperty -Path HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System -Name "LocalAccountTokenFilterPolicy" -Value 0'
          'Write-Host "Reverted LocalAccountTokenFilterPolicy to default."'
        ]
      }
      {
        // Uninstall .Net hosting bundle to avoid vulnerabilites.
        name: 'Uninstall .Net hosting bundle'
        type: 'PowerShell'
        runElevated: true
        runAsSystem: true  
        inline: [
          '$EXE_FILE=Get-ChildItem -Path "C:\\ProgramData\\Package Cache" -Recurse -Filter "*.exe" -File | Where-Object {'
          '  $fileV_FullName -match "hosting" -or $.FullName -match "dotnet"'
          '} | Select-Object -ExpandProperty FullName'
          'if ($EXE_FILE) {'
          '  Write-Host "Found .Net hosting bundle installer at $EXE_FILE"'
          '  Start-Process -FilePath $EXE_FILE -ArgumentList "/uninstall", "/quiet" -Wait'
          '}'
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
