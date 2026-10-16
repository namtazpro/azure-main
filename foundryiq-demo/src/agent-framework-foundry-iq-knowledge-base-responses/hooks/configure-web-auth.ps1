#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

function Invoke-Checked {
    param([scriptblock] $Script, [string] $What)
    & $Script
    if ($LASTEXITCODE -ne 0) {
        throw "$What failed (exit $LASTEXITCODE)."
    }
}

function Get-ConfigValue {
    param([string] $Name)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ($value) {
        return $value
    }

    $line = azd env get-values | Where-Object {
        $_ -match "^$([regex]::Escape($Name))="
    } | Select-Object -First 1
    if ($line -match '^[^=]+="(.*)"$') {
        return $Matches[1]
    }
    return $null
}

$webAppName = Get-ConfigValue "WEB_APP_NAME"
if (-not $webAppName) {
    $webAppName = Get-ConfigValue "SERVICE_WEB_NAME"
}
$resourceGroup = Get-ConfigValue "AZURE_RESOURCE_GROUP"
$tenantId = Get-ConfigValue "AZURE_TENANT_ID"
$environmentName = Get-ConfigValue "AZURE_ENV_NAME"

if (-not $webAppName -or -not $resourceGroup -or -not $tenantId) {
    throw "Web authentication requires WEB_APP_NAME, AZURE_RESOURCE_GROUP, and AZURE_TENANT_ID."
}

$authV2Extension = az extension show --name authV2 --query name -o tsv 2>$null
if ($LASTEXITCODE -ne 0 -or -not $authV2Extension) {
    Invoke-Checked {
        az extension add --name authV2 --yes --allow-preview true
    } "install authV2 extension"
}

$clientId = Get-ConfigValue "WEB_AUTH_CLIENT_ID"
$redirectUri = "https://$webAppName.azurewebsites.net/.auth/login/aad/callback"
$displayName = "foundryiq-demo-web-$environmentName"
$clientSecretSettingName = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
$issuer = "https://login.microsoftonline.com/$tenantId/v2.0"

if (-not $clientId) {
    Write-Host "Creating the tenant-only Entra application '$displayName'..."
    $clientId = az ad app create `
        --display-name $displayName `
        --sign-in-audience AzureADMyOrg `
        --enable-id-token-issuance true `
        --web-redirect-uris $redirectUri `
        --query appId -o tsv
    if ($LASTEXITCODE -ne 0 -or -not $clientId) {
        throw "Creating the Entra application failed."
    }
    Invoke-Checked {
        az ad sp create --id $clientId --output none
    } "service principal create"
    Invoke-Checked {
        azd env set WEB_AUTH_CLIENT_ID $clientId
    } "set WEB_AUTH_CLIENT_ID"
}
else {
    Invoke-Checked {
        az ad app update --id $clientId `
            --enable-id-token-issuance true `
            --web-redirect-uris $redirectUri
    } "update Entra redirect URI"
}

$currentAuthJson = az webapp auth show `
    --resource-group $resourceGroup `
    --name $webAppName `
    --output json 2>$null
if ($LASTEXITCODE -eq 0 -and $currentAuthJson) {
    $currentAuth = $currentAuthJson | ConvertFrom-Json
    $currentAad = $currentAuth.properties.identityProviders.azureActiveDirectory
    if (
        $currentAuth.properties.platform.enabled -and
        $currentAad.registration.clientId -eq $clientId
    ) {
        $configuredSecretSetting = az webapp config appsettings list `
            --resource-group $resourceGroup `
            --name $webAppName `
            --query "[?name=='$clientSecretSettingName'].name | [0]" -o tsv
        $credentialExpirations = az ad app show --id $clientId `
            --query "passwordCredentials[].endDateTime" -o tsv
        $hasCurrentCredential = $credentialExpirations | Where-Object {
            [DateTimeOffset]::Parse($_) -gt [DateTimeOffset]::UtcNow.AddDays(7)
        }
        if (
            $hasCurrentCredential -and
            $configuredSecretSetting -and
            $currentAad.registration.clientSecretSettingName -eq $clientSecretSettingName -and
            $currentAad.registration.openIdIssuer -eq $issuer -and
            $currentAuth.properties.login.tokenStore.enabled
        ) {
            Write-Host "Tenant-only App Service authentication is already configured for $webAppName."
            return
        }
        if (-not $configuredSecretSetting) {
            Write-Host "The Easy Auth client-secret app setting is missing; repairing it."
        }
        else {
            Write-Host "The App Service authentication credential expires within seven days; rotating it."
        }
    }
}

$credentialEndDate = (Get-Date).ToUniversalTime().AddDays(29).ToString(
    "yyyy-MM-ddTHH:mm:ssZ"
)
$clientSecret = az ad app credential reset `
    --id $clientId `
    --append `
    --display-name "App Service auth $environmentName" `
    --end-date $credentialEndDate `
    --query password -o tsv
if ($LASTEXITCODE -ne 0 -or -not $clientSecret) {
    throw "Creating the App Service authentication credential failed."
}

try {
    Invoke-Checked {
        az webapp config appsettings set `
            --resource-group $resourceGroup `
            --name $webAppName `
            --settings "$clientSecretSettingName=$clientSecret" `
            --output none
    } "store Easy Auth client secret"

    $configVersion = az webapp auth config-version show `
        --resource-group $resourceGroup `
        --name $webAppName `
        --query configVersion -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Reading the App Service authentication version failed."
    }
    if ($configVersion -ne "v2") {
        Invoke-Checked {
            az webapp auth config-version upgrade `
                --resource-group $resourceGroup `
                --name $webAppName `
                --output none
        } "upgrade App Service authentication to v2"
    }

    Invoke-Checked {
        az webapp auth microsoft update `
            --resource-group $resourceGroup `
            --name $webAppName `
            --client-id $clientId `
            --client-secret-setting-name $clientSecretSettingName `
            --issuer $issuer `
            --allowed-token-audiences $clientId `
            --yes `
            --output none
    } "configure Microsoft identity provider"

    Invoke-Checked {
        az webapp auth update `
            --resource-group $resourceGroup `
            --name $webAppName `
            --enabled true `
            --unauthenticated-client-action RedirectToLoginPage `
            --redirect-provider aad `
            --enable-token-store true `
            --require-https true `
            --output none
    } "enable App Service authentication"
}
finally {
    $clientSecret = $null
}

Write-Host "Tenant-only App Service authentication is enabled for $webAppName."
