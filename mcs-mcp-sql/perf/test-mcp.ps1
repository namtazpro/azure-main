<#
.SYNOPSIS
    Smoke-tests the AI Gateway MCP endpoint: initialize, tools/list, then optional tools/call with timings.
.EXAMPLE
    $env:AIGW_API_KEY = '<runtime access key>'
    ./perf/test-mcp.ps1 -Url https://<gateway>.azure-api.net/default/toolservers/<server>/mcp
    ./perf/test-mcp.ps1 -Url ... -Tool itsm_searchTickets -Arguments '{"status":"Open","priority":"Critical","pageSize":3}'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Url,
    [string]$ApiKey = $env:AIGW_API_KEY,
    [string]$Tool,
    [string]$Arguments = '{}',
    [int]$Repeat = 1
)

$ErrorActionPreference = 'Stop'
if (-not $ApiKey) { throw 'Set $env:AIGW_API_KEY or pass -ApiKey (runtime access key from the gateway Keys page).' }

$headers = @{ 'api-key' = $ApiKey; 'Accept' = 'application/json, text/event-stream' }
$script:id = 0

function Invoke-Mcp([string]$Method, $Params) {
    $script:id++
    $body = @{ jsonrpc = '2.0'; id = $script:id; method = $Method }
    if ($null -ne $Params) { $body.params = $Params }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-WebRequest $Url -Method Post -Headers $headers -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 20 -Compress) -SkipHttpErrorCheck -TimeoutSec 120
    $ms = [int]$sw.Elapsed.TotalMilliseconds
    if ($r.Headers['Mcp-Session-Id']) { $headers['Mcp-Session-Id'] = [string]$r.Headers['Mcp-Session-Id'] }
    if ($r.StatusCode -ge 400) { throw "HTTP $($r.StatusCode): $($r.Content)" }

    # Streamable HTTP may answer as JSON or as an SSE stream with "data:" lines.
    $text = [string]$r.Content
    if ($text -match '(?m)^data:') { $text = (($text -split "`n" | Where-Object { $_ -like 'data:*' } | Select-Object -Last 1) -replace '^data:\s*', '') }
    [pscustomobject]@{ Ms = $ms; Json = ($text | ConvertFrom-Json -Depth 50) }
}

$init = Invoke-Mcp 'initialize' @{ protocolVersion = '2025-03-26'; capabilities = @{}; clientInfo = @{ name = 'mcp-smoke-test'; version = '1.0' } }
Write-Host ("initialize: {0} ms, server={1}" -f $init.Ms, $init.Json.result.serverInfo.name)
try { Invoke-WebRequest $Url -Method Post -Headers $headers -ContentType 'application/json' -Body '{"jsonrpc":"2.0","method":"notifications/initialized"}' -SkipHttpErrorCheck -TimeoutSec 30 | Out-Null } catch { }

$list = Invoke-Mcp 'tools/list' $null
$tools = $list.Json.result.tools
Write-Host ("tools/list: {0} ms, {1} tools" -f $list.Ms, @($tools).Count)
$tools | ForEach-Object { Write-Host ("  {0}  - {1}" -f $_.name, ($_.description -replace '\s+', ' ').Substring(0, [Math]::Min(80, $_.description.Length))) }

if ($Tool) {
    $toolArgs = $Arguments | ConvertFrom-Json -AsHashtable
    1..$Repeat | ForEach-Object {
        $call = Invoke-Mcp 'tools/call' @{ name = $Tool; arguments = $toolArgs }
        $content = ($call.Json.result.content | ForEach-Object { $_.text }) -join ''
        $isError = [bool]$call.Json.result.isError -or $null -ne $call.Json.error
        Write-Host ("tools/call {0}: {1} ms{2}" -f $Tool, $call.Ms, $(if ($isError) { ' (ERROR)' } else { '' }))
        if ($_ -eq 1) { Write-Host $content.Substring(0, [Math]::Min(600, $content.Length)) }
    }
}
