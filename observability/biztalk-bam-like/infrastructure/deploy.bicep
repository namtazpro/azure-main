// Agentic BAM - Infrastructure Deployment
// Deploys the BAM activity store database and supporting resources
// Equivalent to BizTalk's "bm.exe deploy-all" but using modern IaC

@description('The name prefix for all BAM resources')
param namePrefix string = 'bam'

@description('The Azure region for deployment')
param location string = resourceGroup().location

@description('The SQL administrator login')
param sqlAdminLogin string

@secure()
@description('The SQL administrator password')
param sqlAdminPassword string

@description('Activity definitions to deploy (generates tables)')
param activities array = [
  {
    name: 'SalesOrder'
    milestones: ['Received', 'Validated', 'CreditChecked', 'Approved', 'Dispatched', 'Invoiced']
    dataItems: [
      { name: 'OrderID', type: 'nvarchar(50)' }
      { name: 'CustomerName', type: 'nvarchar(200)' }
      { name: 'CustomerID', type: 'nvarchar(50)' }
      { name: 'OrderAmount', type: 'decimal(18,2)' }
      { name: 'Currency', type: 'nvarchar(3)' }
      { name: 'Region', type: 'nvarchar(10)' }
      { name: 'LineItemCount', type: 'int' }
      { name: 'CreditScore', type: 'int' }
      { name: 'CreditLimit', type: 'decimal(18,2)' }
      { name: 'ApprovedBy', type: 'nvarchar(100)' }
      { name: 'ApprovalType', type: 'nvarchar(20)' }
      { name: 'CarrierName', type: 'nvarchar(100)' }
      { name: 'TrackingNumber', type: 'nvarchar(100)' }
      { name: 'InvoiceNumber', type: 'nvarchar(50)' }
    ]
  }
]

// ─── SQL Server (BAM Activity Store) ──────────────────────────────────────

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: '${namePrefix}-sqlserver'
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: '${namePrefix}-activitystore'
  location: location
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 268435456000 // 250 GB
  }
}

// ─── Application Insights (for interceptor telemetry) ─────────────────────

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${namePrefix}-logs'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 90
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${namePrefix}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ─── Outputs ──────────────────────────────────────────────────────────────

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output databaseName string = sqlDatabase.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
