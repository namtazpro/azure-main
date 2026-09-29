#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys an Azure API Management AI Gateway tier instance.
.DESCRIPTION
    Creates or updates the public-preview Microsoft.ApiManagement/gateways
    resource by using the 2026-05-01-preview Azure Resource Manager API.
    The script requires Azure CLI and an authenticated Microsoft Entra session.
.PARAMETER SubscriptionId
    Azure subscription ID that receives the gateway.
.PARAMETER ResourceGroupName
    Name of the resource group to create or reuse.
.PARAMETER GatewayName
    Globally unique gateway name. The runtime hostname uses this value.
.PARAMETER Location
    Supported AI Gateway preview region.
.PARAMETER Tags
    Optional resource tags.
.PARAMETER TimeoutMinutes
    Maximum time to wait for provisioning to finish.
.EXAMPLE
    ./Deploy-AiGateway.ps1 `
        -SubscriptionId '00000000-0000-0000-0000-000000000000' `
        -ResourceGroupName 'rg-ai-gateway' `
        -GatewayName 'contoso-ai-gateway' `
        -Location 'eastus2'
.NOTES
    AI Gateway tier is a public-preview service without an SLA. As of
    2026-08-24, supported regions are East US 2 and Sweden Central.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z](?:[A-Za-z0-9-]{0,43}[A-Za-z0-9])?$')]
    [string]$GatewayName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('eastus2', 'swedencentral')]
    [string]$Location = 'eastus2',

    [Parameter(Mandatory = $false)]
    [hashtable]$Tags = @{},

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 60)]
    [int]$TimeoutMinutes = 10
)

$ErrorActionPreference = 'Stop'

#region Functions
function Invoke-AzureCli {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $Output = & az @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Arguments -join ' ')`n$($Output -join [Environment]::NewLine)"
    }

    return $Output -join [Environment]::NewLine
}

function Get-AiGateway {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceUrl
    )

    $Json = Invoke-AzureCli -Arguments @(
        'rest',
        '--method', 'get',
        '--url', $ResourceUrl,
        '--output', 'json'
    )

    return $Json | ConvertFrom-Json
}

function Enable-AiGatewayPreview {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 60)]
        [int]$TimeoutMinutes
    )

    $FeatureName = 'AIGatewayPreview'
    $FeatureState = Invoke-AzureCli -Arguments @(
        'feature', 'show',
        '--namespace', 'Microsoft.ApiManagement',
        '--name', $FeatureName,
        '--query', 'properties.state',
        '--output', 'tsv'
    )

    if ($FeatureState -eq 'Registered') {
        return
    }

    Write-Host 'Registering the Microsoft.ApiManagement/AIGatewayPreview feature...'
    Invoke-AzureCli -Arguments @(
        'feature', 'register',
        '--namespace', 'Microsoft.ApiManagement',
        '--name', $FeatureName,
        '--output', 'none'
    ) | Out-Null

    $Deadline = [DateTimeOffset]::UtcNow.AddMinutes($TimeoutMinutes)
    do {
        $FeatureState = Invoke-AzureCli -Arguments @(
            'feature', 'show',
            '--namespace', 'Microsoft.ApiManagement',
            '--name', $FeatureName,
            '--query', 'properties.state',
            '--output', 'tsv'
        )
        Write-Host "Preview feature state: $FeatureState"

        if ($FeatureState -eq 'Registered') {
            break
        }
        if ($FeatureState -notin @('NotRegistered', 'Registering', 'Pending')) {
            throw "AI Gateway preview feature registration ended with state '$FeatureState'."
        }
        if ([DateTimeOffset]::UtcNow -ge $Deadline) {
            throw "AI Gateway preview registration is still '$FeatureState' after $TimeoutMinutes minutes. Check its status with: az feature show --namespace Microsoft.ApiManagement --name $FeatureName"
        }

        Start-Sleep -Seconds 10
    } while ($true)
}
#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
            throw 'Azure CLI is required. Install it from https://aka.ms/installazurecli.'
        }

        Invoke-AzureCli -Arguments @('account', 'show', '--output', 'none') | Out-Null
        Invoke-AzureCli -Arguments @('account', 'set', '--subscription', $SubscriptionId) | Out-Null

        $TenantId = Invoke-AzureCli -Arguments @(
            'account', 'show', '--query', 'tenantId', '--output', 'tsv'
        )
        Write-Host "Using subscription $SubscriptionId in tenant $TenantId."

        if (-not $PSCmdlet.ShouldProcess(
                "$GatewayName in $ResourceGroupName ($Location)",
                'Deploy AI Gateway public-preview resource')) {
            return
        }

        Enable-AiGatewayPreview -TimeoutMinutes $TimeoutMinutes

        Write-Host 'Registering the Microsoft.ApiManagement resource provider...'
        Invoke-AzureCli -Arguments @(
            'provider', 'register',
            '--namespace', 'Microsoft.ApiManagement',
            '--wait'
        ) | Out-Null

        Write-Host "Creating or updating resource group '$ResourceGroupName'..."
        Invoke-AzureCli -Arguments @(
            'group', 'create',
            '--name', $ResourceGroupName,
            '--location', $Location,
            '--output', 'none'
        ) | Out-Null

        $ApiVersion = '2026-05-01-preview'
        $ResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ApiManagement/gateways/$GatewayName"
        $ResourceUrl = "https://management.azure.com${ResourceId}?api-version=$ApiVersion"
        $RequestBody = @{
            location   = $Location
            sku        = @{
                name = 'AI'
                tier = 'AI'
            }
            identity   = @{
                type = 'SystemAssigned'
            }
            properties = @{}
            tags       = $Tags
        } | ConvertTo-Json -Depth 10

        $BodyPath = Join-Path ([System.IO.Path]::GetTempPath()) "ai-gateway-$([guid]::NewGuid()).json"
        try {
            Set-Content -LiteralPath $BodyPath -Value $RequestBody -Encoding utf8NoBOM
            Write-Host "Deploying AI Gateway '$GatewayName'..."
            Invoke-AzureCli -Arguments @(
                'rest',
                '--method', 'put',
                '--url', $ResourceUrl,
                '--headers', 'Content-Type=application/json',
                '--body', "@$BodyPath",
                '--output', 'none'
            ) | Out-Null
        }
        finally {
            Remove-Item -LiteralPath $BodyPath -Force -ErrorAction SilentlyContinue
        }

        $Deadline = [DateTimeOffset]::UtcNow.AddMinutes($TimeoutMinutes)
        do {
            $Gateway = Get-AiGateway -ResourceUrl $ResourceUrl
            $ProvisioningState = $Gateway.properties.provisioningState
            if ([string]::IsNullOrWhiteSpace($ProvisioningState)) {
                $ProvisioningState = 'Succeeded'
            }

            Write-Host "Provisioning state: $ProvisioningState"
            if ($ProvisioningState -eq 'Succeeded') {
                break
            }
            if ($ProvisioningState -in @('Failed', 'Canceled')) {
                throw "Gateway provisioning ended with state '$ProvisioningState'."
            }
            if ([DateTimeOffset]::UtcNow -ge $Deadline) {
                throw "Gateway provisioning did not complete within $TimeoutMinutes minutes."
            }

            Start-Sleep -Seconds 10
        } while ($true)

        $RuntimeEndpoint = if ($Gateway.properties.runtimeEndpoint) {
            $Gateway.properties.runtimeEndpoint
        }
        elseif ($Gateway.properties.gatewayUrl) {
            $Gateway.properties.gatewayUrl
        }
        else {
            "https://$GatewayName.azure-api.net"
        }

        [pscustomobject]@{
            Name             = $GatewayName
            ResourceId       = $Gateway.id
            Location         = $Gateway.location
            ProvisioningState = $ProvisioningState
            RuntimeEndpoint  = $RuntimeEndpoint
            ManagementPortal = 'https://ai.gateway.azure.com'
            ApiVersion       = $ApiVersion
        }
    }
    catch {
        Write-Error -ErrorAction Continue "AI Gateway deployment failed: $($_.Exception.Message)"
        exit 1
    }
}
#endregion Main Execution