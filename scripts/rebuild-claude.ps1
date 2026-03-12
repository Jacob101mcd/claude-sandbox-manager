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

$port = Register-Instance $name
$port = Resolve-Port $name $port
Ensure-SshKeys $name
Ensure-Workspace $name
Write-DockerCompose $name $port
Stage-SshKeys $name

cd $Script:Root
docker compose down --remove-orphans
docker compose build --no-cache
docker compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[X] Rebuild failed." -ForegroundColor Red
    pause; exit 1
}

Write-Host "`n[OK] Rebuild complete! Instance '$name' running on port $port." -ForegroundColor Green
docker ps --filter "name=$(Get-ContainerName $name)"

Write-SshConfig $name $port
