targetScope = 'subscription'

@minLength(1)
@maxLength(40)
@description('Name of the azd environment, used to derive resource names.')
param environmentName string

@minLength(1)
@description('Primary Azure region for all resources.')
param location string

@description('UPN of the Microsoft Entra user that becomes the SQL server admin.')
param sqlAdminLogin string

@description('Object id of the Microsoft Entra user that becomes the SQL server admin.')
param sqlAdminObjectId string

@description('Database SKU. Use a provisioned (non-serverless) tier so performance numbers are not skewed by auto-pause.')
param sqlSkuName string = 'GP_Gen5_2'

@description('App Service plan SKU for the Functions app. Dedicated plans keep the app always warm.')
param planSkuName string = 'P0v3'

var tags = { 'azd-env-name': environmentName }
var token = toLower(uniqueString(subscription().id, environmentName, location))

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: 'log-${token}'
    appInsightsName: 'appi-${token}'
  }
}

module identity 'modules/identity.bicep' = {
  name: 'identity'
  scope: rg
  params: {
    location: location
    tags: tags
    name: 'id-api-${token}'
  }
}

module network 'modules/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    location: location
    tags: tags
    vnetName: 'vnet-${token}'
  }
}

module sql 'modules/sql.bicep' = {
  name: 'sql'
  scope: rg
  params: {
    location: location
    tags: tags
    serverName: 'sql-${token}'
    databaseName: 'itsmdb'
    skuName: sqlSkuName
    adminLogin: sqlAdminLogin
    adminObjectId: sqlAdminObjectId
    logAnalyticsId: monitoring.outputs.logAnalyticsId
    peSubnetId: network.outputs.peSubnetId
    dnsZoneId: network.outputs.sqlDnsZoneId
  }
}

module api 'modules/api.bicep' = {
  name: 'api'
  scope: rg
  params: {
    location: location
    tags: tags
    planName: 'plan-${token}'
    planSkuName: planSkuName
    functionAppName: 'func-${token}'
    storageName: 'st${token}'
    identityId: identity.outputs.id
    identityPrincipalId: identity.outputs.principalId
    identityClientId: identity.outputs.clientId
    funcSubnetId: network.outputs.funcSubnetId
    peSubnetId: network.outputs.peSubnetId
    blobDnsZoneId: network.outputs.blobDnsZoneId
    queueDnsZoneId: network.outputs.queueDnsZoneId
    tableDnsZoneId: network.outputs.tableDnsZoneId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    sqlConnectionString: 'Server=tcp:${sql.outputs.fqdn},1433;Database=${sql.outputs.databaseName};Authentication=Active Directory Managed Identity;User Id=${identity.outputs.clientId};Encrypt=True;Connect Timeout=30;'
  }
}

output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = rg.name
output SQL_SERVER_FQDN string = sql.outputs.fqdn
output SQL_DATABASE_NAME string = sql.outputs.databaseName
output VNET_NAME string = 'vnet-${token}'
output API_IDENTITY_NAME string = identity.outputs.name
output API_IDENTITY_CLIENT_ID string = identity.outputs.clientId
output API_FUNCTION_APP_NAME string = api.outputs.functionAppName
output API_BASE_URL string = 'https://${api.outputs.defaultHostname}'
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.appInsightsName
