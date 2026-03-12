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
Stage-SshKeys $name

$containerName = Get-ContainerName $name
$imageName = "claude-sandbox-$name"
$wsDir = (Get-WorkspaceDir $name) -replace '\\', '/'

# Stop and remove existing container
docker stop $containerName 2>$null
docker rm $containerName 2>$null

# Rebuild image from scratch
docker build --no-cache -t $imageName -f "$Script:Root\scripts\Dockerfile" "$Script:Root"

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[X] Rebuild failed." -ForegroundColor Red
    pause; exit 1
}

# Run new container
docker run -d --name $containerName `
    -p "${port}:22" `
    -v "${wsDir}:/home/claude/workspace" `
    -w /home/claude/workspace `
    --restart unless-stopped `
    $imageName

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[X] Failed to start container." -ForegroundColor Red
    pause; exit 1
}

Write-Host "`n[OK] Rebuild complete! Instance '$name' running on port $port." -ForegroundColor Green
docker ps --filter "name=$containerName"

Write-SshConfig $name $port
