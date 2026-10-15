<#
.SYNOPSIS
    Deploys the ITSM schema, stored procedures and demo data to the private Azure SQL database.
.DESCRIPTION
    The SQL server has public access disabled (tenant policy), so the SQL scripts run from a short-lived
    Azure Container Instance injected into the VNet. Runs as the azd postprovision hook or standalone.
    The signed-in user must be the Microsoft Entra admin of the SQL server (`az login` / `azd auth login`).
    Your Entra access token is passed to the container as a secure environment variable; the container is deleted afterwards.
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup,
    [string]$VnetName,
    [string]$SqlServerFqdn,
    [string]$DatabaseName,
    [string]$ApiIdentityName,
    [string]$ApiIdentityClientId,
    [switch]$Reseed
)

$ErrorActionPreference = 'Stop'

function Get-AzdValue([string]$Name) {
    $line = azd env get-values 2>$null | Where-Object { $_ -like "$Name=*" } | Select-Object -First 1
    if ($line) { return ($line -replace "^$Name=", '').Trim('"') }
}

if (-not $ResourceGroup) { $ResourceGroup = Get-AzdValue 'AZURE_RESOURCE_GROUP' }
if (-not $VnetName) { $VnetName = Get-AzdValue 'VNET_NAME' }
if (-not $SqlServerFqdn) { $SqlServerFqdn = Get-AzdValue 'SQL_SERVER_FQDN' }
if (-not $DatabaseName) { $DatabaseName = Get-AzdValue 'SQL_DATABASE_NAME' }
if (-not $ApiIdentityName) { $ApiIdentityName = Get-AzdValue 'API_IDENTITY_NAME' }
if (-not $ApiIdentityClientId) { $ApiIdentityClientId = Get-AzdValue 'API_IDENTITY_CLIENT_ID' }

foreach ($required in 'ResourceGroup', 'VnetName', 'SqlServerFqdn', 'DatabaseName', 'ApiIdentityName', 'ApiIdentityClientId') {
    if (-not (Get-Variable $required -ValueOnly)) { throw "Missing required value: $required" }
}

function ConvertTo-Base64([string]$Path) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Get-Content $Path -Raw))) }

$token = az account get-access-token --resource 'https://database.windows.net/' --query accessToken -o tsv
if (-not $token) { throw 'Could not get an access token. Run az login first.' }

az provider register --namespace Microsoft.ContainerInstance --wait --only-show-errors | Out-Null

$procs = 'usp_GetTicket', 'usp_SearchTickets', 'usp_GetTicketComments', 'usp_SearchCustomers', 'usp_GetTicketsByCustomer',
         'usp_GetAgentWorkload', 'usp_GetTicketSummary', 'usp_GetSlaBreaches', 'usp_CreateTicket', 'usp_UpdateTicketStatus'

$name = "aci-dbdeploy-$([guid]::NewGuid().ToString('N').Substring(0, 6))"
$subnetId = az network vnet subnet show -g $ResourceGroup --vnet-name $VnetName -n snet-deploy --query id -o tsv

function New-EnvEntry([string]$Name, [string]$Value, [bool]$Secure) {
    $prop = if ($Secure) { 'secureValue' } else { 'value' }
    "          - name: $Name`n            ${prop}: '$Value'"
}

$plain = [ordered]@{
    SQL_SERVER_FQDN        = $SqlServerFqdn
    SQL_DATABASE_NAME      = $DatabaseName
    API_IDENTITY_NAME      = $ApiIdentityName
    API_IDENTITY_CLIENT_ID = $ApiIdentityClientId
    API_PROCS              = ($procs -join ',')
    SEED_FORCE             = [string][int]$Reseed.IsPresent
}
$secret = [ordered]@{
    SQL_ACCESS_TOKEN = $token
    RUNNER           = ConvertTo-Base64 (Join-Path $PSScriptRoot 'run-sql.ps1')
    SQL_FILE_SCHEMA  = ConvertTo-Base64 (Join-Path $PSScriptRoot '01-schema.sql')
    SQL_FILE_PROCS   = ConvertTo-Base64 (Join-Path $PSScriptRoot '02-procs.sql')
    SQL_FILE_SEED    = ConvertTo-Base64 (Join-Path $PSScriptRoot '03-seed.sql')
}
$envYaml = (@($plain.Keys | ForEach-Object { New-EnvEntry $_ $plain[$_] $false }) + @($secret.Keys | ForEach-Object { New-EnvEntry $_ $secret[$_] $true })) -join "`n"
$location = az network vnet show -g $ResourceGroup -n $VnetName --query location -o tsv

# A spec file avoids the Windows command-line length limit; it holds a token, so it is deleted in the finally block.
$specPath = Join-Path ([IO.Path]::GetTempPath()) "$name.yaml"
@"
apiVersion: '2023-05-01'
location: $location
name: $name
properties:
  osType: Linux
  restartPolicy: Never
  subnetIds:
    - id: $subnetId
  containers:
    - name: runner
      properties:
        image: mcr.microsoft.com/powershell:lts-ubuntu-22.04
        command:
          - pwsh
          - -NoProfile
          - -Command
          - '[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$env:RUNNER)) | Invoke-Expression'
        resources:
          requests:
            cpu: 1
            memoryInGB: 2
        environmentVariables:
$envYaml
type: Microsoft.ContainerInstance/containerGroups
"@ | Set-Content $specPath

Write-Host "Starting VNet container $name to run the SQL scripts (first start pulls the image, ~2-3 minutes)..."
try {
    az container create -g $ResourceGroup --file $specPath --only-show-errors | Out-Null
    $state = ''
    for ($i = 0; $i -lt 120; $i++) {
        $state = az container show -g $ResourceGroup -n $name --query "containers[0].instanceView.currentState.state" -o tsv
        if ($state -eq 'Terminated') { break }
        Start-Sleep 10
    }

    $logs = az container logs -g $ResourceGroup -n $name --only-show-errors
    $logs | Write-Host
    if (-not ($logs -match 'DB_DEPLOY_OK')) { throw 'Database deployment did not complete successfully. See container logs above.' }
}
finally {
    Remove-Item $specPath -Force -ErrorAction SilentlyContinue
    az container delete -g $ResourceGroup -n $name --yes --only-show-errors 2>$null | Out-Null
}
Write-Host 'Database deployment complete.'
