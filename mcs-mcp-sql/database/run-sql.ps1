# Runs inside the VNet container started by deploy-db.ps1. Do not run directly.
$ErrorActionPreference = 'Stop'

function Decode([string]$b64) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)) }

Install-Module SqlServer -Scope CurrentUser -Force -AllowClobber -Repository PSGallery | Out-Null
Import-Module SqlServer

$conn = @{
    ServerInstance = $env:SQL_SERVER_FQDN
    Database       = $env:SQL_DATABASE_NAME
    AccessToken    = $env:SQL_ACCESS_TOKEN
    QueryTimeout   = 1800
    ErrorAction    = 'Stop'
}

# Retry while the private endpoint / DNS settle.
for ($i = 1; $i -le 10; $i++) {
    try { Invoke-Sqlcmd @conn -Query 'SELECT 1' | Out-Null; break }
    catch { if ($i -eq 10) { throw }; Write-Host "SQL not reachable yet (attempt $i): $($_.Exception.Message)"; Start-Sleep 15 }
}

# SQL files are batch scripts separated by GO, which Invoke-Sqlcmd handles.
foreach ($name in 'SCHEMA', 'PROCS', 'SEED') {
    Write-Host "Applying $name..."
    Invoke-Sqlcmd @conn -Query (Decode (Get-Item "env:SQL_FILE_$name").Value)
}

$identity = $env:API_IDENTITY_NAME
$sid = '0x' + ((([guid]$env:API_IDENTITY_CLIENT_ID).ToByteArray() | ForEach-Object { $_.ToString('X2') }) -join '')
$procs = $env:API_PROCS -split ','
$grants = ($procs | ForEach-Object { "GRANT EXECUTE ON OBJECT::dbo.$_ TO [$identity];" }) -join "`n"

Write-Host "Granting EXECUTE on API procedures to $identity..."
Invoke-Sqlcmd @conn -Query @"
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$identity')
    CREATE USER [$identity] WITH SID = $sid, TYPE = E;
$grants
"@

Write-Host 'Seeding demo data (skipped when data already exists)...'
Invoke-Sqlcmd @conn -Query "EXEC dbo.usp_SeedDemoData @Force = $($env:SEED_FORCE);" | Format-Table | Out-String | Write-Host
Write-Host 'DB_DEPLOY_OK'
