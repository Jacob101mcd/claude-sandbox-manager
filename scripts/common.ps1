# Common functions for multi-instance Claude Sandbox management

$Script:Root = Split-Path -Parent $PSScriptRoot
$Script:InstancesFile = "$Script:Root\.instances.json"

function Get-Instances {
    if (Test-Path $Script:InstancesFile) {
        return (Get-Content $Script:InstancesFile -Raw | ConvertFrom-Json)
    }
    return [PSCustomObject]@{}
}

function Save-Instances($Instances) {
    $Instances | ConvertTo-Json -Depth 10 | Set-Content $Script:InstancesFile -Encoding UTF8
}

function Test-PortAvailable($Port) {
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
        $listener.Start()
        $listener.Stop()
        return $true
    } catch {
        return $false
    }
}

function Get-NextFreePort {
    $instances = Get-Instances
    $usedPorts = @()
    $instances.PSObject.Properties | ForEach-Object { $usedPorts += $_.Value.port }
    $port = 2222
    while (($usedPorts -contains $port) -or -not (Test-PortAvailable $port)) { $port++ }
    return $port
}

function Resolve-Port($Name, $Port) {
    if (Test-PortAvailable $Port) { return $Port }

    Write-Host "`n[!] Port $Port is already in use on this machine." -ForegroundColor Yellow
    $nextFree = Get-NextFreePort
    Write-Host "    Next available port: $nextFree" -ForegroundColor Cyan
    $choice = Read-Host "    Enter port to use (or press Enter for $nextFree)"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $newPort = $nextFree
    } else {
        $newPort = [int]$choice
    }

    $instances = Get-Instances
    $instances.PSObject.Properties[$Name].Value.port = $newPort
    Save-Instances $instances

    Write-Host "[OK] Instance '$Name' reassigned to port $newPort" -ForegroundColor Green
    return $newPort
}

function Get-ContainerName($Name) {
    return "claude-sandbox-$Name"
}

function Get-SshAlias($Name) {
    if ($Name -eq "default") { return "claude-sandbox" }
    return "claude-$Name"
}

function Get-SshDir($Name) {
    return "$Script:Root\ssh\$Name"
}

function Get-WorkspaceDir($Name) {
    return "$Script:Root\workspaces\$Name"
}

function Get-BackupDir($Name) {
    return "$Script:Root\backups\$Name"
}

function Get-ContainerStatus($Name) {
    $containerName = Get-ContainerName $Name
    $status = docker inspect --format '{{.State.Status}}' $containerName 2>$null
    if ($LASTEXITCODE -ne 0) { return "not created" }
    return $status
}

function Show-InstanceList {
    $instances = Get-Instances
    $props = @($instances.PSObject.Properties)
    if ($props.Count -eq 0) {
        Write-Host "  (no instances registered)" -ForegroundColor Gray
        return
    }
    foreach ($prop in $props) {
        $name = $prop.Name
        $port = $prop.Value.port
        $status = Get-ContainerStatus $name
        $color = switch ($status) {
            "running" { "Green" }
            "exited"  { "Yellow" }
            default   { "Gray" }
        }
        $alias = Get-SshAlias $name
        Write-Host "  [$name]" -ForegroundColor Cyan -NoNewline
        Write-Host "  port $port  " -NoNewline
        Write-Host $status -ForegroundColor $color -NoNewline
        Write-Host "  (ssh $alias)"
    }
}

function Select-Instance($Prompt) {
    $instances = Get-Instances
    $props = @($instances.PSObject.Properties)
    if ($props.Count -eq 0) {
        Write-Host "No instances found." -ForegroundColor Red
        return $null
    }
    if ($props.Count -eq 1) {
        $name = $props[0].Name
        Write-Host "Using instance: $name" -ForegroundColor Cyan
        return $name
    }
    Write-Host "`n$Prompt" -ForegroundColor Cyan
    for ($i = 0; $i -lt $props.Count; $i++) {
        $name = $props[$i].Name
        $port = $props[$i].Value.port
        $status = Get-ContainerStatus $name
        $color = switch ($status) {
            "running" { "Green" }
            "exited"  { "Yellow" }
            default   { "Gray" }
        }
        Write-Host "  [$($i+1)] $name  (port $port, " -NoNewline
        Write-Host $status -ForegroundColor $color -NoNewline
        Write-Host ")"
    }
    $choice = Read-Host "`nEnter number"
    $index = [int]$choice - 1
    if ($index -lt 0 -or $index -ge $props.Count) {
        Write-Host "Invalid choice." -ForegroundColor Red
        return $null
    }
    return $props[$index].Name
}

function Register-Instance($Name) {
    $instances = Get-Instances
    if ($instances.PSObject.Properties[$Name]) {
        return $instances.PSObject.Properties[$Name].Value.port
    }
    $port = Get-NextFreePort
    $instances | Add-Member -NotePropertyName $Name -NotePropertyValue ([PSCustomObject]@{ port = $port })
    Save-Instances $instances
    Write-Host "Registered instance '$Name' on port $port" -ForegroundColor Green
    return $port
}

function Unregister-Instance($Name) {
    $instances = Get-Instances
    if (-not $instances.PSObject.Properties[$Name]) { return }
    $newInstances = [PSCustomObject]@{}
    $instances.PSObject.Properties | Where-Object { $_.Name -ne $Name } | ForEach-Object {
        $newInstances | Add-Member -NotePropertyName $_.Name -NotePropertyValue $_.Value
    }
    Save-Instances $newInstances
}


function Ensure-SshKeys($Name) {
    $sshDir = Get-SshDir $Name
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }

    if (-not (Test-Path "$sshDir\id_claude")) {
        Write-Host "Generating SSH user keypair for '$Name'..." -ForegroundColor Yellow
        ssh-keygen -t ed25519 -f "$sshDir\id_claude" -N '""' -C "claude-sandbox-$Name"
        Write-Host "[OK] SSH user keypair generated." -ForegroundColor Green
    }

    if (-not (Test-Path "$sshDir\ssh_host_ed25519_key")) {
        Write-Host "Generating SSH host key for '$Name'..." -ForegroundColor Yellow
        ssh-keygen -t ed25519 -f "$sshDir\ssh_host_ed25519_key" -N '""' -C "claude-sandbox-$Name-host"
        Write-Host "[OK] SSH host key generated." -ForegroundColor Green
    }
}

function Ensure-Workspace($Name) {
    $wsDir = Get-WorkspaceDir $Name
    if (-not (Test-Path $wsDir)) { New-Item -ItemType Directory -Path $wsDir | Out-Null }
}

function Stage-SshKeys($Name) {
    $src = Get-SshDir $Name
    $dst = "$Script:Root\_build_ssh"
    if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
    New-Item -ItemType Directory -Path $dst | Out-Null
    Copy-Item "$src\*" $dst
}

function Write-SshConfig($Name, $Port) {
    $sshConfigPath = "$env:USERPROFILE\.ssh\config"
    $keyPath = "$(Get-SshDir $Name)\id_claude"
    $alias = Get-SshAlias $Name

    $hostBlock = @"

Host $alias
  HostName localhost
  Port $Port
  User claude
  IdentityFile $keyPath
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
"@

    if (-not (Test-Path "$env:USERPROFILE\.ssh")) {
        New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" | Out-Null
    }

    # Remove all existing blocks for this alias, then re-add
    if (Test-Path $sshConfigPath) {
        $lines = Get-Content $sshConfigPath -ErrorAction SilentlyContinue
        if ($lines) {
            $filtered = @()
            $skipping = $false
            foreach ($line in $lines) {
                if ($line -match "^Host\s+$([regex]::Escape($alias))\s*$") {
                    $skipping = $true
                    continue
                }
                if ($skipping -and $line -match "^Host\s+") {
                    $skipping = $false
                }
                if ($skipping -and $line -match "^\s") {
                    continue
                }
                if ($skipping) {
                    $skipping = $false
                }
                $filtered += $line
            }
            # Remove trailing blank lines
            while ($filtered.Count -gt 0 -and $filtered[-1].Trim() -eq "") {
                $filtered = $filtered[0..($filtered.Count - 2)]
            }
            Set-Content -Path $sshConfigPath -Value ($filtered -join "`r`n") -Encoding UTF8 -NoNewline
        }
    }

    Add-Content -Path $sshConfigPath -Value $hostBlock
    Write-Host "[OK] SSH config for '$alias' written to $sshConfigPath" -ForegroundColor Green

    icacls $keyPath /inheritance:r /grant:r "${env:USERNAME}:(R)" 2>$null | Out-Null
}

function Start-SandboxInstance($Name) {
    $port = Register-Instance $Name
    $port = Resolve-Port $Name $port
    Ensure-SshKeys $Name
    Ensure-Workspace $Name
    Stage-SshKeys $Name

    $containerName = Get-ContainerName $Name
    $imageName = "claude-sandbox-$Name"
    $wsDir = (Get-WorkspaceDir $Name) -replace '\\', '/'

    # Build image for this instance
    docker build -t $imageName -f "$Script:Root\scripts\Dockerfile" "$Script:Root"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[X] Docker build failed." -ForegroundColor Red
        return $false
    }

    # Stop and remove existing container if present
    docker stop $containerName 2>$null
    docker rm $containerName 2>$null

    # Run new container
    docker run -d --name $containerName `
        -p "${port}:22" `
        -v "${wsDir}:/home/claude/workspace" `
        -w /home/claude/workspace `
        --restart unless-stopped `
        $imageName

    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[X] Docker run failed." -ForegroundColor Red
        return $false
    }

    Write-Host "`n[OK] Instance '$Name' is running! (port $port)" -ForegroundColor Green
    docker ps --filter "name=$containerName"

    Write-SshConfig $Name $port

    # Clear stale Claude Desktop host trust so it re-prompts for the new key
    $ClaudeSshConfigs = "$env:APPDATA\Claude\ssh_configs.json"
    if (Test-Path $ClaudeSshConfigs) {
        $cfg = Get-Content $ClaudeSshConfigs -Raw | ConvertFrom-Json
        if ($cfg.trustedHosts -contains "claude@localhost") {
            $cfg.trustedHosts = @($cfg.trustedHosts | Where-Object { $_ -ne "claude@localhost" })
            $cfg | ConvertTo-Json -Depth 10 | Set-Content $ClaudeSshConfigs -Encoding UTF8
            Write-Host "NOTE: Cleared stale Claude Desktop host trust - you will be prompted to accept the host key once in Claude Desktop." -ForegroundColor Yellow
        }
    }

    return $true
}

function Invoke-WorkspaceMigration {
    $oldWorkspace = "$Script:Root\workspace"
    $newWorkspace = Get-WorkspaceDir "default"
    if ((Test-Path $oldWorkspace) -and -not (Test-Path $newWorkspace)) {
        Write-Host "Migrating workspace/ to workspaces/default/..." -ForegroundColor Yellow
        if (-not (Test-Path "$Script:Root\workspaces")) {
            New-Item -ItemType Directory -Path "$Script:Root\workspaces" | Out-Null
        }
        Move-Item -Path $oldWorkspace -Destination $newWorkspace
        Write-Host "[OK] Workspace migrated." -ForegroundColor Green
    }
}

function Test-DockerRunning {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[X] Docker Desktop is not running. Please start it and try again." -ForegroundColor Red
        return $false
    }
    return $true
}
