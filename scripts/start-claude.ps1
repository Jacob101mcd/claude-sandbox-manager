. "$PSScriptRoot\common.ps1"

Write-Host "=== Claude Sandbox Starter ===" -ForegroundColor Green

if (-not (Test-DockerRunning)) { pause; exit 1 }

# Auto-migrate old single-instance workspace on first run
Invoke-WorkspaceMigration

# If no instances exist, auto-register default
$instances = Get-Instances
if (@($instances.PSObject.Properties).Count -eq 0) {
    Register-Instance "default" | Out-Null
}

$name = Select-Instance "Select instance to start:"
if (-not $name) { pause; exit 1 }

$result = Start-SandboxInstance $name

# Clear stale Claude Desktop host trust
$ClaudeSshConfigs = "$env:APPDATA\Claude\ssh_configs.json"
if (Test-Path $ClaudeSshConfigs) {
    $cfg = Get-Content $ClaudeSshConfigs -Raw | ConvertFrom-Json
    if ($cfg.trustedHosts -contains "claude@localhost") {
        $cfg.trustedHosts = @($cfg.trustedHosts | Where-Object { $_ -ne "claude@localhost" })
        $cfg | ConvertTo-Json -Depth 10 | Set-Content $ClaudeSshConfigs -Encoding UTF8
        Write-Host "NOTE: Cleared stale Claude Desktop host trust - you will be prompted to accept the host key once in Claude Desktop." -ForegroundColor Yellow
    }
}

if (-not $result) { pause; exit 1 }

Write-Host "`nReconnect Claude Desktop now."
