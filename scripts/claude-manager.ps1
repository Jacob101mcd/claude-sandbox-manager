. "$PSScriptRoot\common.ps1"

Write-Host "`n=== Claude Sandbox Manager ===" -ForegroundColor Green

if (-not (Test-DockerRunning)) { pause; exit 1 }

# Auto-migrate old single-instance workspace on first run
Invoke-WorkspaceMigration

# If no instances exist yet, auto-register default
$instances = Get-Instances
if (@($instances.PSObject.Properties).Count -eq 0) {
    Write-Host "No instances found. Creating 'default' instance..." -ForegroundColor Yellow
    Register-Instance "default" | Out-Null
}

while ($true) {
    Write-Host "`n--- Instances ---" -ForegroundColor Cyan
    Show-InstanceList

    Write-Host "`n--- Actions ---" -ForegroundColor Cyan
    Write-Host "  [S] Start an instance"
    Write-Host "  [T] Stop an instance"
    Write-Host "  [N] Create new instance"
    Write-Host "  [R] Remove an instance"
    Write-Host "  [Q] Quit"

    $action = Read-Host "`nChoice"

    switch ($action.ToUpper()) {
        "S" {
            $name = Select-Instance "Select instance to start:"
            if ($name) {
                Start-SandboxInstance $name | Out-Null
            }
        }
        "T" {
            $name = Select-Instance "Select instance to stop:"
            if ($name) {
                $containerName = Get-ContainerName $name
                Write-Host "Stopping $containerName..." -ForegroundColor Yellow
                docker stop $containerName 2>$null
                Write-Host "[OK] Stopped." -ForegroundColor Green
            }
        }
        "N" {
            $name = Read-Host "Enter instance name (lowercase, no spaces)"
            $name = $name.Trim().ToLower() -replace '[^a-z0-9-]', ''
            if (-not $name) {
                Write-Host "Invalid name." -ForegroundColor Red
                continue
            }
            $existing = Get-Instances
            if ($existing.PSObject.Properties[$name]) {
                Write-Host "Instance '$name' already exists." -ForegroundColor Red
                continue
            }
            Start-SandboxInstance $name | Out-Null
        }
        "R" {
            $name = Select-Instance "Select instance to remove:"
            if (-not $name) { continue }
            $confirm = Read-Host "Remove instance '$name'? This stops the container and deregisters it. Type YES to confirm"
            if ($confirm -ne "YES") {
                Write-Host "Cancelled." -ForegroundColor Yellow
                continue
            }

            $containerName = Get-ContainerName $name
            docker stop $containerName 2>$null
            docker rm $containerName 2>$null

            # Remove SSH config entry
            $alias = Get-SshAlias $name
            $sshConfigPath = "$env:USERPROFILE\.ssh\config"
            if (Test-Path $sshConfigPath) {
                $content = Get-Content $sshConfigPath -Raw -ErrorAction SilentlyContinue
                if ($content -and $content.Contains("Host $alias")) {
                    $content = $content -replace "(?m)\r?\nHost $([regex]::Escape($alias))\r?\n(?:  [^\r\n]+\r?\n)*", ""
                    Set-Content -Path $sshConfigPath -Value $content.TrimEnd() -Encoding UTF8
                    Write-Host "Removed SSH config for '$alias'." -ForegroundColor Green
                }
            }

            Unregister-Instance $name

            $deleteFiles = Read-Host "Also delete workspace and backups for '$name'? (y/N)"
            if ($deleteFiles -eq "y" -or $deleteFiles -eq "Y") {
                $wsDir = Get-WorkspaceDir $name
                $bkDir = Get-BackupDir $name
                $sshDir = Get-SshDir $name
                if (Test-Path $wsDir) { Remove-Item $wsDir -Recurse -Force }
                if (Test-Path $bkDir) { Remove-Item $bkDir -Recurse -Force }
                if (Test-Path $sshDir) {
                    # Reset restrictive ACLs set by icacls during key setup
                    Get-ChildItem $sshDir -Recurse -File | ForEach-Object { icacls $_.FullName /reset 2>$null | Out-Null }
                    Remove-Item $sshDir -Recurse -Force
                }
                Write-Host "Deleted files for '$name'." -ForegroundColor Green
            }

            Write-Host "[OK] Instance '$name' removed." -ForegroundColor Green
        }
        "Q" { exit 0 }
        default { Write-Host "Invalid choice." -ForegroundColor Red }
    }
}
