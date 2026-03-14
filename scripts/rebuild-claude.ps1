. "$PSScriptRoot\common.ps1"

Write-Host "=== Rebuilding Claude Sandbox ===" -ForegroundColor Cyan

if (-not (Test-DockerRunning)) { pause; exit 1 }

Invoke-WorkspaceMigration

$instances = Get-Instances
if (@($instances.PSObject.Properties).Count -eq 0) {
    Register-Instance "default" | Out-Null
}

$name = Select-Instance "Select instance to rebuild:"
if (-not $name) { pause; exit 1 }

# Delegate to Start-SandboxInstance which handles type-aware builds,
# VNC port mapping, security hardening, and port resolution
$ok = Start-SandboxInstance $name
if (-not $ok) {
    Write-Host "`n[X] Rebuild failed." -ForegroundColor Red
    pause; exit 1
}

$type    = Get-InstanceType $name
$vncPort = Get-InstanceVncPort $name
if ($type -eq "gui" -and $vncPort) {
    Write-Host "[OK] noVNC desktop: http://localhost:$vncPort" -ForegroundColor Green
} else {
    $alias = Get-SshAlias $name
    Write-Host "Connect via: ssh $alias" -ForegroundColor Cyan
}
