. "$PSScriptRoot\common.ps1"

Write-Host "`n=== Claude Sandbox Manager ===" -ForegroundColor Green

if (-not (Test-DockerRunning)) { pause; exit 1 }

# Auto-migrate old single-instance workspace on first run
Invoke-WorkspaceMigration

# Ensure config file exists before any settings reads
Ensure-ConfigFile

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
    Write-Host "  [B] Backup an instance"
    Write-Host "  [E] Restore an instance"
    Write-Host "  [P] Preferences"
    Write-Host "  [Q] Quit"

    $action = Read-Host "`nChoice"

    switch ($action.ToUpper()) {
        "S" {
            $name = Select-Instance "Select instance to start:"
            if ($name) {
                $ok = Start-SandboxInstance $name
                if ($ok) {
                    $type    = Get-InstanceType $name
                    $vncPort = Get-InstanceVncPort $name
                    if ($type -eq "gui" -and $vncPort) {
                        Write-Host "[OK] noVNC desktop: http://localhost:$vncPort" -ForegroundColor Green
                        $answer = Read-Host "Open in browser? (y/N)"
                        if ($answer -eq "y" -or $answer -eq "Y") {
                            Start-Process "http://localhost:$vncPort"
                        }
                    } else {
                        $alias = Get-SshAlias $name
                        Write-Host "Connect via: ssh $alias" -ForegroundColor Cyan
                    }
                }
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

            # Prompt for container type
            $type = Select-ContainerType

            # Register with type before starting
            Register-Instance $name $type | Out-Null

            $ok = Start-SandboxInstance $name
            if ($ok) {
                $vncPort = Get-InstanceVncPort $name
                if ($type -eq "gui" -and $vncPort) {
                    Write-Host "[OK] noVNC desktop: http://localhost:$vncPort" -ForegroundColor Green
                    $answer = Read-Host "Open in browser? (y/N)"
                    if ($answer -eq "y" -or $answer -eq "Y") {
                        Start-Process "http://localhost:$vncPort"
                    }
                } else {
                    $alias = Get-SshAlias $name
                    Write-Host "Connect via: ssh $alias" -ForegroundColor Cyan
                }
            }
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

            # Clean up copied SSH key from ~/.ssh/<alias>/
            $safeKeyDir = "$env:USERPROFILE\.ssh\$alias"
            if (Test-Path $safeKeyDir) {
                Get-ChildItem $safeKeyDir -Recurse -File | ForEach-Object { icacls $_.FullName /reset 2>$null | Out-Null }
                Remove-Item $safeKeyDir -Recurse -Force
                Write-Host "Removed SSH key copy from $safeKeyDir" -ForegroundColor Green
            }

            $deleteFiles = Read-Host "Also delete workspace and backups for '$name'? (y/N)"
            if ($deleteFiles -eq "y" -or $deleteFiles -eq "Y") {
                $wsDir  = Get-WorkspaceDir $name
                $bkDir  = Get-BackupDir $name
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
        "B" {
            $name = Select-Instance "Select instance to back up:"
            if ($name) {
                Invoke-Backup $name | Out-Null
            }
        }
        "E" {
            $name = Select-Instance "Select instance to restore:"
            if (-not $name) { continue }

            $backupDirs = Get-BackupList $name
            if ($backupDirs.Count -eq 0) { continue }

            $choice = Read-Host "`nSelect backup number"
            if ($choice -notmatch '^[0-9]+$' -or [int]$choice -lt 1 -or [int]$choice -gt $backupDirs.Count) {
                Write-Host "Invalid selection." -ForegroundColor Red
                continue
            }
            $selectedDir = $backupDirs[[int]$choice - 1]

            Write-Host "[!] This will REPLACE the current instance with the selected backup." -ForegroundColor Yellow
            $confirm = Read-Host "Type YES to confirm restore"
            if ($confirm -ne "YES") {
                Write-Host "Cancelled." -ForegroundColor Yellow
                continue
            }

            $ok = Invoke-Restore $name $selectedDir
            if ($ok) {
                $type    = Get-InstanceType $name
                $vncPort = Get-InstanceVncPort $name
                if ($type -eq "gui" -and $vncPort) {
                    Write-Host "[OK] noVNC desktop: http://localhost:$vncPort" -ForegroundColor Green
                    $answer = Read-Host "Open in browser? (y/N)"
                    if ($answer -eq "y" -or $answer -eq "Y") {
                        Start-Process "http://localhost:$vncPort"
                    }
                } else {
                    $alias = Get-SshAlias $name
                    Write-Host "Connect via: ssh $alias" -ForegroundColor Cyan
                }
            }
        }
        "P" {
            Show-PreferencesMenu
        }
        "Q" { exit 0 }
        default { Write-Host "Invalid choice." -ForegroundColor Red }
    }
}
