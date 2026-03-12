. "$PSScriptRoot\common.ps1"

Write-Host "=== Claude Sandbox Restore ===" -ForegroundColor Cyan

$instances = Get-Instances
if (@($instances.PSObject.Properties).Count -eq 0) {
    Write-Host "No instances found." -ForegroundColor Red
    pause; exit 1
}

$name = Select-Instance "Select instance to restore:"
if (-not $name) { pause; exit 1 }

$BackupsDir = Get-BackupDir $name
if (-not (Test-Path $BackupsDir)) {
    Write-Host "No backups found for '$name'." -ForegroundColor Red
    pause; exit 1
}

$BackupFolders = Get-ChildItem $BackupsDir -Directory | Sort-Object LastWriteTime -Descending
if ($BackupFolders.Count -eq 0) {
    Write-Host "No backups found for '$name'." -ForegroundColor Red
    pause; exit 1
}

Write-Host "`n=== Available Backups for '$name' (newest first) ===" -ForegroundColor Cyan
for ($i = 0; $i -lt $BackupFolders.Count; $i++) {
    $size = [math]::Round((Get-ChildItem $BackupFolders[$i].FullName -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
    Write-Host "[$($i+1)] $($BackupFolders[$i].Name)  ($size MB)"
}

$choice = Read-Host "`nEnter the number of the backup to restore"
$index = [int]$choice - 1
if ($index -lt 0 -or $index -ge $BackupFolders.Count) {
    Write-Host "Invalid choice" -ForegroundColor Red
    pause; exit 1
}

$Selected = $BackupFolders[$index]
$TagFile = Join-Path $Selected.FullName "tag.txt"
$ImageTag = if (Test-Path $TagFile) { (Get-Content $TagFile -Raw).Trim() } else { "$(Get-ContainerName $name)-backup-$($Selected.Name)" }

$WorkspaceZip = Join-Path $Selected.FullName "workspace.zip"
$ImageZip = Join-Path $Selected.FullName "image.tar.zip"

Write-Host "`nYou selected: $($Selected.Name)" -ForegroundColor Yellow
Write-Host "WARNING: This will STOP the container and OVERWRITE the workspace for '$name'!" -ForegroundColor Red
$confirm = Read-Host "Type YES to continue"
if ($confirm -ne "YES") { Write-Host "Cancelled."; pause; exit }

$containerName = Get-ContainerName $name
$port = Register-Instance $name

# Stop & remove current container
docker stop $containerName 2>$null
docker rm $containerName 2>$null

# Load Docker image
Write-Host "Loading Docker image..."
Expand-Archive -Path $ImageZip -DestinationPath $Selected.FullName -Force
$ImageTar = Join-Path $Selected.FullName "image.tar"
docker load -i $ImageTar
Remove-Item $ImageTar -Force

# Restore workspace
$wsDir = Get-WorkspaceDir $name
Write-Host "Restoring workspace files..."
Remove-Item "$wsDir\*" -Recurse -Force -ErrorAction SilentlyContinue
if (Test-Path $WorkspaceZip) {
    $tempDir = "$env:TEMP\claude-restore-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Expand-Archive -Path $WorkspaceZip -DestinationPath $tempDir -Force
    if (Test-Path "$tempDir\workspace") {
        Copy-Item "$tempDir\workspace\*" $wsDir -Recurse -Force
    } else {
        Copy-Item "$tempDir\*" $wsDir -Recurse -Force
    }
    Remove-Item $tempDir -Recurse -Force
} else {
    Write-Host "No workspace.zip found (old backup) - creating empty workspace" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $wsDir -Force | Out-Null
}

# Start container from backup
Write-Host "Starting container from backup..."
docker run -d --name $containerName `
  -p "${port}:22" `
  -v "${wsDir}:/home/claude/workspace" `
  --restart unless-stopped `
  $ImageTag

Write-Host "[OK] Restore complete! Instance '$name' running on port $port." -ForegroundColor Green
Write-Host "Reconnect Claude Desktop now."
