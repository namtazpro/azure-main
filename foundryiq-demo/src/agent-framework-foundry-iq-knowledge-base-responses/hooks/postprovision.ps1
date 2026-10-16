#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

function Invoke-Checked {
    param([scriptblock] $Script, [string] $What)
    & $Script
    if ($LASTEXITCODE -ne 0) {
        throw "$What failed (exit $LASTEXITCODE)."
    }
}

function Test-Toolbox {
    param([string] $Name)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    azd ai toolbox show $Name *> $null
    $exists = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $previous
    return $exists
}

function New-ToolboxFromTemplate {
    param(
        [string] $Name,
        [string] $TemplatePath,
        [string] $KnowledgeBaseEndpoint
    )
    if (Test-Toolbox $Name) {
        Write-Host "Toolbox $Name already exists; skipping create."
        return
    }

    $resolved = (Get-Content $TemplatePath -Raw).Replace(
        '${KB_MCP_ENDPOINT}',
        $KnowledgeBaseEndpoint
    )
    $tempFile = Join-Path (
        [System.IO.Path]::GetTempPath()
    ) "toolbox-$Name-$([System.Guid]::NewGuid()).yaml"
    Set-Content -Path $tempFile -Value $resolved -NoNewline
    try {
        Invoke-Checked {
            azd ai toolbox create $Name --from-file $tempFile
        } "toolbox create $Name"
    }
    finally {
        Remove-Item -LiteralPath $tempFile -ErrorAction SilentlyContinue
    }
}

Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not $env:AZURE_SEARCH_ENDPOINT) {
    throw "AZURE_SEARCH_ENDPOINT was not exported by infrastructure provisioning."
}
if (-not $env:FOUNDRY_PROJECT_ENDPOINT) {
    throw "FOUNDRY_PROJECT_ENDPOINT was not exported by Foundry provisioning."
}
if (-not $env:AZURE_OPENAI_ENDPOINT) {
    $env:AZURE_OPENAI_ENDPOINT = (
        $env:FOUNDRY_PROJECT_ENDPOINT `
            -replace '\.services\.ai\.azure\.com/api/projects/.*$', '.openai.azure.com'
    )
}

Write-Host "Provisioning the travel-policy Foundry IQ knowledge base..."
$provisioned = $false
for ($attempt = 1; $attempt -le 6; $attempt++) {
    uv run --no-project `
        --with azure-identity `
        --with python-dotenv `
        --with requests `
        python provision_kb.py
    if ($LASTEXITCODE -eq 0) {
        $provisioned = $true
        break
    }
    if ($attempt -lt 6) {
        Write-Warning "Knowledge provisioning attempt $attempt failed; waiting for RBAC propagation."
        Start-Sleep -Seconds 20
    }
}
if (-not $provisioned) {
    throw "Knowledge-base provisioning failed after RBAC propagation retries."
}

$kbEndpoint = azd env get-value KB_MCP_ENDPOINT
if (-not $kbEndpoint) {
    throw "provision_kb.py did not set KB_MCP_ENDPOINT."
}

Write-Host "Creating the project-managed knowledge-base connection..."
Invoke-Checked {
    azd ai connection create knowledge-base-mcp --kind remote-tool --force `
        --target $kbEndpoint --auth-type project-managed-identity `
        --audience https://search.azure.com --metadata "ApiType=Azure"
} "knowledge-base connection create"

Write-Host "Creating the Work IQ Mail user-identity connection..."
Invoke-Checked {
    azd ai connection create workiq-mail-mcp --kind remote-tool --force `
        --target https://workiq.svc.cloud.microsoft/mcp `
        --auth-type user-entra-token `
        --audience fdcc1f02-fc51-4226-8753-f668596af7f7
} "Work IQ connection create"

New-ToolboxFromTemplate `
    -Name "knowledge-base" `
    -TemplatePath "./toolbox.yaml" `
    -KnowledgeBaseEndpoint $kbEndpoint
New-ToolboxFromTemplate `
    -Name "travel-policy-full" `
    -TemplatePath "./toolbox-full.yaml" `
    -KnowledgeBaseEndpoint $kbEndpoint

$projectEndpoint = (azd env get-value FOUNDRY_PROJECT_ENDPOINT).TrimEnd("/")
$knowledgeToolbox = "$projectEndpoint/toolboxes/knowledge-base/mcp?api-version=v1"
$fullToolbox = "$projectEndpoint/toolboxes/travel-policy-full/mcp?api-version=v1"
Invoke-Checked {
    azd env set TOOLBOX_ENDPOINT $knowledgeToolbox
} "set TOOLBOX_ENDPOINT"
Invoke-Checked {
    azd env set FULL_TOOLBOX_ENDPOINT $fullToolbox
} "set FULL_TOOLBOX_ENDPOINT"

if ($env:SKIP_WEB_AUTH -ne "true") {
    & "$PSScriptRoot/configure-web-auth.ps1"
}

Write-Host "Foundry IQ provisioning completed."
Write-Host "Knowledge toolbox: $knowledgeToolbox"
Write-Host "Full toolbox: $fullToolbox"
