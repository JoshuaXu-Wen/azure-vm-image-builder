param privateDnsZoneStorageAccountName string = 'privatelink.blob.${az.environment().suffixes.storage}'
param environment string = 'dev'
param vnetId string
param tags object


// Private DNS Zone (in different resource group)
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneStorageAccountName
  tags: tags
  location: 'global'
}

// DNS Zone VNet Link
resource dnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${environment}-vnetlink'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

output privateDnsZoneId string = privateDnsZone.id
