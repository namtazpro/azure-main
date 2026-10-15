param location string
param tags object
param planName string
param planSkuName string
param functionAppName string
param storageName string
param identityId string
param identityPrincipalId string
param identityClientId string
param funcSubnetId string
param peSubnetId string
param blobDnsZoneId string
param queueDnsZoneId string
param tableDnsZoneId string
param appInsightsConnectionString string
@secure()
param sqlConnectionString string

var storageRoles = [
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Storage Blob Data Owner
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88' // Storage Queue Data Contributor
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3' // Storage Table Data Contributor
]

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Disabled'
    networkAcls: { defaultAction: 'Deny', bypass: 'AzureServices' }
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource storageRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in storageRoles: {
  name: guid(storage.id, identityPrincipalId, role)
  scope: storage
  properties: {
    principalId: identityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
  }
}]

var storageEndpoints = [
  { group: 'blob', zoneId: blobDnsZoneId }
  { group: 'queue', zoneId: queueDnsZoneId }
  { group: 'table', zoneId: tableDnsZoneId }
]

module storageEndpointModules 'private-endpoint.bicep' = [for ep in storageEndpoints: {
  name: 'pe-st-${ep.group}'
  params: {
    location: location
    tags: tags
    name: 'pe-${storageName}-${ep.group}'
    targetResourceId: storage.id
    groupId: ep.group
    subnetId: peSubnetId
    dnsZoneId: ep.zoneId
  }
}]
resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'linux'
  sku: { name: planSkuName }
  properties: { reserved: true }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: union(tags, { 'azd-service-name': 'api' })
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${identityId}': {} }
  }
  properties: {
    serverFarmId: plan.id
    virtualNetworkSubnetId: funcSubnetId
    vnetRouteAllEnabled: true
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNET-ISOLATED|9.0'
      alwaysOn: true
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'dotnet-isolated' }
        { name: 'AzureWebJobsStorage__accountName', value: storage.name }
        { name: 'AzureWebJobsStorage__credential', value: 'managedidentity' }
        { name: 'AzureWebJobsStorage__clientId', value: identityClientId }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
        { name: 'SqlConnectionString', value: sqlConnectionString }
      ]
    }
  }
  dependsOn: [storageRoleAssignments, storageEndpointModules]
}

output functionAppName string = functionApp.name
output defaultHostname string = functionApp.properties.defaultHostName
