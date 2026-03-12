. "$PSScriptRoot\common.ps1"

Write-Host "=== Claude Sandbox Backup ===" -ForegroundColor Green

if (-not (Test-DockerRunning)) { pause; exit 1 }

$instances = Get-Instances
if (@($instances.PSObject.Properties).Count -eq 0) {
    Write-Host "No instances found." -ForegroundColor Red
    pause; exit 1
}

$name = Select-Instance "Select instance to back up:"
if (-not $name) { pause; exit 1 }

$Timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$BackupDir = "$(Get-BackupDir $name)\$Timestamp"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

$containerName = Get-ContainerName $name

# Commit container state
$ImageTag = "$containerName-backup-$Timestamp"
docker commit $containerName $ImageTag

# Save + compress Docker image
docker save $ImageTag -o "$BackupDir\image.tar"
Compress-Archive -Path "$BackupDir\image.tar" -DestinationPath "$BackupDir\image.tar.zip" -CompressionLevel Optimal -Force
Remove-Item "$BackupDir\image.tar" -Force

# Backup workspace
Add-Type -Assembly System.IO.Compression.FileSystem
$WorkspaceRoot = Get-WorkspaceDir $name
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

# Save metadata
@{ imagetag = $ImageTag; instance = $name; port = (Get-InstanceConfig $name) } |
    ConvertTo-Json | Set-Content "$BackupDir\metadata.json" -Encoding UTF8
$ImageTag | Out-File "$BackupDir\tag.txt" -Encoding utf8

Write-Host "[OK] Backup complete! Saved to: $BackupDir" -ForegroundColor Green
