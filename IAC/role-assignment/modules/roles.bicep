// Azure Image Builder Roles
targetScope = 'subscription'

resource azureImageBuilderRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' = {
  name: guid(subscription().subscriptionId, 'Azure Image Builder Role')
  properties: {
    roleName: 'Azure Image Builder Role'
    description: 'Custom role for Azure Image Builder to manage resources during image creation'
    type: 'customRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/galleries/read'
          'Microsoft.Compute/galleries/images/read'
          'Microsoft.Compute/galleries/images/versions/read'
          'Microsoft.Compute/galleries/images/versions/write'

          'Microsoft.Compute/images/write'
          'Microsoft.Compute/images/read'
          'Microsoft.Compute/images/delete'
        ]
        notActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

resource azureNetworkRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' = {
  name: guid(subscription().subscriptionId, 'Azure Network Role')
  properties: {
    roleName: 'Azure Network Role'
    description: 'Custom role for Azure Network to manage resources during image creation'
    type: 'customRole'
    permissions: [
      {
        actions: [
          'Microsoft.Network/virtualNetworks/subnets/join/action'
          'Microsoft.Network/virtualNetworks/subnets/read'
          'Microsoft.Network/virtualNetworks/read'

        ]
        notActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}


output roleDefinitionId string = azureImageBuilderRole.id
output networkRoleDefinitionId string = azureNetworkRole.id
