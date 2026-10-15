<#
.SYNOPSIS
    Measures API latency (p50/p95/p99) per endpoint, with optional concurrency. No extra tooling required.
.EXAMPLE
    ./perf/measure-api.ps1 -Iterations 50 -Concurrency 5
#>
[CmdletBinding()]
param(
    [string]$BaseUrl,
    [string]$FunctionKey,
    [int]$Iterations = 30,
    [int]$Concurrency = 1,
    [int]$Warmup = 3
)

$ErrorActionPreference = 'Stop'

function Get-AzdValue([string]$Name) {
    $line = azd env get-values 2>$null | Where-Object { $_ -like "$Name=*" } | Select-Object -First 1
    if ($line) { return ($line -replace "^$Name=", '').Trim('"') }
}

if (-not $BaseUrl) { $BaseUrl = Get-AzdValue 'API_BASE_URL' }
if (-not $FunctionKey) {
    $FunctionKey = az functionapp keys list -g (Get-AzdValue 'AZURE_RESOURCE_GROUP') -n (Get-AzdValue 'API_FUNCTION_APP_NAME') --query 'functionKeys.default' -o tsv
}
if (-not $BaseUrl -or -not $FunctionKey) { throw 'BaseUrl and FunctionKey are required (or run from an azd environment).' }

$endpoints = [ordered]@{
    'getTicket'          = '/api/tickets/INC-000123'
    'searchTickets'      = '/api/tickets?status=Open&priority=High&pageSize=10'
    'getTicketComments'  = '/api/tickets/INC-000123/comments'
    'searchCustomers'    = '/api/customers?name=Alice&top=10'
    'getCustomerTickets' = '/api/customers/42/tickets?top=10'
    'getAgentWorkload'   = '/api/agents/workload?team=Service%20Desk'
    'getTicketSummary'   = '/api/reports/summary'
    'getSlaBreaches'     = '/api/reports/sla-breaches?top=10'
}

$results = foreach ($name in $endpoints.Keys) {
    $url = "$($BaseUrl.TrimEnd('/'))$($endpoints[$name])"
    1..$Warmup | ForEach-Object { try { Invoke-WebRequest $url -Headers @{ 'x-functions-key' = $FunctionKey } -TimeoutSec 60 | Out-Null } catch { } }

    $samples = 1..$Iterations | ForEach-Object -ThrottleLimit $Concurrency -Parallel {
        $status = 0; $err = $null; $ms = 0
        # Retry only client-side DNS failures, restarting the timer so resolver glitches never pollute latency.
        for ($attempt = 1; $attempt -le 5; $attempt++) {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            try {
                $status = (Invoke-WebRequest $using:url -Headers @{ 'x-functions-key' = $using:FunctionKey } -TimeoutSec 60 -SkipHttpErrorCheck).StatusCode
                $err = $null
            }
            catch { $err = $_.Exception.Message }
            $ms = $sw.Elapsed.TotalMilliseconds
            if (-not $err -or $err -notmatch 'requested name is valid|No such host|name resolution') { break }
            Start-Sleep -Milliseconds 300
        }
        [pscustomobject]@{ Ms = $ms; Ok = ($status -eq 200); Status = $status; Err = $err }
    }

    $firstBad = $samples | Where-Object { -not $_.Ok } | Select-Object -First 1
    if ($firstBad) { Write-Warning "$name failing: status=$($firstBad.Status) $($firstBad.Err)" }

    $sorted = @($samples.Ms | Sort-Object)
    $pick = { param($p) $sorted[[Math]::Min($sorted.Count - 1, [int][Math]::Ceiling($p * $sorted.Count) - 1)] }
    [pscustomobject]@{
        Operation = $name
        Count     = $sorted.Count
        Errors    = @($samples | Where-Object { -not $_.Ok }).Count
        'p50 ms'  = [int](& $pick 0.50)
        'p95 ms'  = [int](& $pick 0.95)
        'p99 ms'  = [int](& $pick 0.99)
        'max ms'  = [int]$sorted[-1]
    }
}

$results | Format-Table -AutoSize
