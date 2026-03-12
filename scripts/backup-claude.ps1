$Root = Split-Path -Parent $PSScriptRoot
$Timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$BackupDir = "$Root\backups\$Timestamp"

# Check Docker is running
docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Docker Desktop is not running. Please start it and try again." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

Write-Host "=== Claude Sandbox Backup: $Timestamp ===" -ForegroundColor Green

# Commit container state
$ImageTag = "claude-sandbox-backup-$Timestamp"
docker commit claude-sandbox $ImageTag

# Save + compress Docker image
docker save $ImageTag -o "$BackupDir\image.tar"
Compress-Archive -Path "$BackupDir\image.tar" -DestinationPath "$BackupDir\image.tar.zip" -CompressionLevel Optimal -Force
Remove-Item "$BackupDir\image.tar" -Force

# Backup workspace
Add-Type -Assembly System.IO.Compression.FileSystem
$WorkspaceRoot = "$Root\workspace"
$ZipPath = "$BackupDir\workspace.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
$zip = [System.IO.Compression.ZipFile]::Open($ZipPath, 'Create')
$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
Get-ChildItem -Path $WorkspaceRoot -Recurse -File |
    ForEach-Object {
        $relativePath = $_.FullName.Substring($WorkspaceRoot.Length + 1)
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $_.FullName, $relativePath, $compressionLevel
        )
    }
$zip.Dispose()

# Save clean tag
$ImageTag | Out-File "$BackupDir\tag.txt" -Encoding utf8

Write-Host "[OK] Backup complete! Saved to: $BackupDir" -ForegroundColor Green
