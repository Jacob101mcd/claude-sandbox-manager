$Root = Split-Path -Parent $PSScriptRoot
$BackupsDir = "$Root\backups"

$BackupFolders = Get-ChildItem $BackupsDir -Directory | Sort-Object LastWriteTime -Descending

if ($BackupFolders.Count -eq 0) {
    Write-Host "No backups found!" -ForegroundColor Red
    pause; exit
}

Write-Host "=== Available Backups (newest first) ===" -ForegroundColor Cyan
for ($i = 0; $i -lt $BackupFolders.Count; $i++) {
    $size = [math]::Round((Get-ChildItem $BackupFolders[$i].FullName -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
    Write-Host "[$($i+1)] $($BackupFolders[$i].Name)  ($size MB)"
}

$choice = Read-Host "`nEnter the number of the backup to restore"
$index = [int]$choice - 1
if ($index -lt 0 -or $index -ge $BackupFolders.Count) {
    Write-Host "Invalid choice" -ForegroundColor Red
    pause; exit
}

$Selected = $BackupFolders[$index]
$TagFile = Join-Path $Selected.FullName "tag.txt"
$ImageTag = if (Test-Path $TagFile) { (Get-Content $TagFile -Raw).Trim() } else { "claude-sandbox-backup-$($Selected.Name)" }

$WorkspaceZip = Join-Path $Selected.FullName "workspace.zip"
$ImageZip = Join-Path $Selected.FullName "image.tar.zip"

Write-Host "`nYou selected: $($Selected.Name)" -ForegroundColor Yellow
Write-Host "WARNING: This will STOP your container and OVERWRITE everything in workspace!" -ForegroundColor Red
$confirm = Read-Host "Type YES to continue"
if ($confirm -ne "YES") { Write-Host "Cancelled."; pause; exit }

# Stop & remove current container
docker stop claude-sandbox 2>$null
docker rm claude-sandbox 2>$null

# Load Docker image
Write-Host "Loading Docker image..."
Expand-Archive -Path $ImageZip -DestinationPath $Selected.FullName -Force
$ImageTar = Join-Path $Selected.FullName "image.tar"
docker load -i $ImageTar
Remove-Item $ImageTar -Force

# Restore workspace (handles old backups without workspace.zip)
Write-Host "Restoring workspace files..."
Remove-Item "$Root\workspace\*" -Recurse -Force -ErrorAction SilentlyContinue
if (Test-Path $WorkspaceZip) {
    $tempDir = "$env:TEMP\claude-restore-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Expand-Archive -Path $WorkspaceZip -DestinationPath $tempDir -Force
    if (Test-Path "$tempDir\workspace") {
        Copy-Item "$tempDir\workspace\*" "$Root\workspace" -Recurse -Force
    }
    Remove-Item $tempDir -Recurse -Force
} else {
    Write-Host "No workspace.zip found (old backup) - creating empty workspace" -ForegroundColor Gray
    New-Item -ItemType Directory -Path "$Root\workspace" -Force | Out-Null
}

# Start container from backup
Write-Host "Starting container from backup..."
docker run -d --name claude-sandbox `
  -p 2222:22 `
  -v "${Root}\workspace:/home/claude/workspace" `
  --restart unless-stopped `
  $ImageTag

Write-Host "[OK] Restore complete! Reconnect Claude Desktop now." -ForegroundColor Green
