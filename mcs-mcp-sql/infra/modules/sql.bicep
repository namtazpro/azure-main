param location string
param tags object
param serverName string
param databaseName string
param skuName string
param adminLogin string
param adminObjectId string
param logAnalyticsId string
param peSubnetId string
param dnsZoneId string

resource server 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: serverName
  location: location
  tags: tags
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: adminLogin
      sid: adminObjectId
      tenantId: tenant().tenantId
      principalType: 'User'
    }
  }
}

resource database 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: server
  name: databaseName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 34359738368
    zoneRedundant: false
  }
}

module privateEndpoint 'private-endpoint.bicep' = {
  name: 'pe-sql'
  params: {
    location: location
    tags: tags
    name: 'pe-${serverName}'
    targetResourceId: server.id
    groupId: 'sqlServer'
    subnetId: peSubnetId
    dnsZoneId: dnsZoneId
  }
}
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-log-analytics'
  scope: database
  properties: {
    workspaceId: logAnalyticsId
    metrics: [
      { category: 'Basic', enabled: true }
    ]
    logs: [
      { category: 'QueryStoreRuntimeStatistics', enabled: true }
      { category: 'Errors', enabled: true }
    ]
  }
}

output fqdn string = server.properties.fullyQualifiedDomainName
output databaseName string = database.name
