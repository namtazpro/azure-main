param location string
param tags object
param vnetName string

var privateDnsZones = [
  'privatelink${environment().suffixes.sqlServerHostname}'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.queue.${environment().suffixes.storage}'
  'privatelink.table.${environment().suffixes.storage}'
]

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: ['10.10.0.0/16'] }
    subnets: [
      {
        name: 'snet-func'
        properties: {
          addressPrefix: '10.10.1.0/24'
          delegations: [
            { name: 'web', properties: { serviceName: 'Microsoft.Web/serverFarms' } }
          ]
        }
      }
      {
        name: 'snet-pe'
        properties: { addressPrefix: '10.10.2.0/24' }
      }
      {
        name: 'snet-deploy'
        properties: {
          addressPrefix: '10.10.3.0/24'
          delegations: [
            { name: 'aci', properties: { serviceName: 'Microsoft.ContainerInstance/containerGroups' } }
          ]
        }
      }
    ]
  }
}

resource zones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in privateDnsZones: {
  name: zone
  location: 'global'
  tags: tags
}]

resource links 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in privateDnsZones: {
  parent: zones[i]
  name: 'link-${vnetName}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnet.id }
  }
}]

output funcSubnetId string = '${vnet.id}/subnets/snet-func'
output peSubnetId string = '${vnet.id}/subnets/snet-pe'
output sqlDnsZoneId string = zones[0].id
output blobDnsZoneId string = zones[1].id
output queueDnsZoneId string = zones[2].id
output tableDnsZoneId string = zones[3].id
