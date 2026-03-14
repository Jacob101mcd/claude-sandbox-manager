# Common functions for multi-instance Claude Sandbox management

$Script:Root = Split-Path -Parent $PSScriptRoot
$Script:InstancesFile = "$Script:Root\.instances.json"
$Script:EnvFile = "$Script:Root\.env"
$Script:ConfigFile = "$Script:Root\csm-config.json"

# ===========================================================================
# Instance registry
# ===========================================================================

function Get-Instances {
    if (Test-Path $Script:InstancesFile) {
        return (Get-Content $Script:InstancesFile -Raw | ConvertFrom-Json)
    }
    return [PSCustomObject]@{}
}

function Save-Instances($Instances) {
    $Instances | ConvertTo-Json -Depth 10 | Set-Content $Script:InstancesFile -Encoding UTF8
}

# ===========================================================================
# Port helpers
# ===========================================================================

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

function Get-NextFreeVncPort {
    $instances = Get-Instances
    $usedPorts = @()
    $instances.PSObject.Properties | ForEach-Object {
        if ($_.Value.PSObject.Properties["vnc_port"] -and $_.Value.vnc_port) {
            $usedPorts += $_.Value.vnc_port
        }
    }
    $port = 6080
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

function Resolve-VncPort($Name, $Port) {
    if (-not $Port) { return $null }
    if (Test-PortAvailable $Port) { return $Port }

    Write-Host "`n[!] VNC port $Port is already in use on this machine." -ForegroundColor Yellow
    $nextFree = Get-NextFreeVncPort
    Write-Host "    Next available VNC port: $nextFree" -ForegroundColor Cyan
    $choice = Read-Host "    Enter VNC port to use (or press Enter for $nextFree)"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $newPort = $nextFree
    } else {
        $newPort = [int]$choice
    }

    $instances = Get-Instances
    $instances.PSObject.Properties[$Name].Value.vnc_port = $newPort
    Save-Instances $instances

    Write-Host "[OK] Instance '$Name' VNC reassigned to port $newPort" -ForegroundColor Green
    return $newPort
}

# ===========================================================================
# Path helpers
# ===========================================================================

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

# ===========================================================================
# Config file management (port from lib/settings.sh)
# ===========================================================================

function Ensure-ConfigFile {
    if (Test-Path $Script:ConfigFile) { return }

    $config = [PSCustomObject]@{
        defaults     = [PSCustomObject]@{
            container_type = $null
            memory_limit   = "2g"
            cpu_limit      = 2
        }
        backup       = [PSCustomObject]@{
            auto_backup = $false
        }
        integrations = [PSCustomObject]@{
            mcp_port = 8811
        }
    }

    $tmp = "$Script:ConfigFile.tmp"
    $config | ConvertTo-Json -Depth 10 | Set-Content $tmp -Encoding UTF8
    Move-Item -Force $tmp $Script:ConfigFile
    Write-Host "[!] Created csm-config.json with defaults." -ForegroundColor Yellow
}

function _Get-ConfigObject {
    if (-not (Test-Path $Script:ConfigFile)) { return $null }
    return (Get-Content $Script:ConfigFile -Raw | ConvertFrom-Json)
}

function _Save-ConfigObject($Config) {
    $tmp = "$Script:ConfigFile.tmp"
    $Config | ConvertTo-Json -Depth 10 | Set-Content $tmp -Encoding UTF8
    Move-Item -Force $tmp $Script:ConfigFile
}

function Get-Setting($JqPath) {
    # Parse dotted path like ".defaults.memory_limit" into segments
    $config = _Get-ConfigObject
    if (-not $config) { return "" }

    # Strip leading dot and split
    $path = $JqPath.TrimStart('.')
    $segments = $path -split '\.'

    $current = $config
    foreach ($seg in $segments) {
        if (-not $seg) { continue }
        $prop = $current.PSObject.Properties[$seg]
        if (-not $prop) { return "" }
        $current = $prop.Value
        if ($null -eq $current) { return "" }
    }
    if ($null -eq $current) { return "" }
    return "$current"
}

function Get-SettingBool($JqPath) {
    $config = _Get-ConfigObject
    if (-not $config) { return "false" }

    $path = $JqPath.TrimStart('.')
    $segments = $path -split '\.'

    $current = $config
    foreach ($seg in $segments) {
        if (-not $seg) { continue }
        $prop = $current.PSObject.Properties[$seg]
        if (-not $prop) { return "false" }
        $current = $prop.Value
        if ($null -eq $current) { return "false" }
    }
    if ($current -eq $true) { return "true" }
    return "false"
}

function Set-Setting($JqPath, $Value) {
    $config = _Get-ConfigObject
    if (-not $config) { return }

    $path = $JqPath.TrimStart('.')
    $segments = $path -split '\.'

    # Navigate to parent object, then set the leaf
    $current = $config
    for ($i = 0; $i -lt $segments.Count - 1; $i++) {
        $seg = $segments[$i]
        if (-not $seg) { continue }
        $prop = $current.PSObject.Properties[$seg]
        if (-not $prop) {
            $current | Add-Member -NotePropertyName $seg -NotePropertyValue ([PSCustomObject]@{})
            $current = $current.PSObject.Properties[$seg].Value
        } else {
            $current = $prop.Value
        }
    }

    $leaf = $segments[-1]
    if ($current.PSObject.Properties[$leaf]) {
        $current.PSObject.Properties[$leaf].Value = $Value
    } else {
        $current | Add-Member -NotePropertyName $leaf -NotePropertyValue $Value
    }

    _Save-ConfigObject $config
}

# ===========================================================================
# Container type selection (port from lib/menu.sh)
# ===========================================================================

function Select-ContainerType {
    $defaultType = Get-Setting '.defaults.container_type'

    if ($defaultType -and $defaultType -ne "") {
        $label = if ($defaultType -eq "gui") { "GUI Desktop" } else { "Minimal CLI" }
        Write-Host "-> Using default: $label" -ForegroundColor Cyan
        Write-Host "   Change in [P] Preferences" -ForegroundColor Gray
        return $defaultType
    }

    Write-Host "`nSelect container type:" -ForegroundColor Cyan
    Write-Host "  [1] Minimal CLI"
    Write-Host "  [2] GUI Desktop"
    Write-Host ""
    $choice = Read-Host "Type [1]"
    switch ($choice) {
        "2"   { return "gui" }
        default { return "cli" }
    }
}

# ===========================================================================
# Preferences menu (port from lib/settings.sh)
# ===========================================================================

function _Show-PreferencesDisplay {
    $autoBk  = Get-SettingBool '.backup.auto_backup'
    $ctype   = Get-Setting '.defaults.container_type'
    $mem     = Get-Setting '.defaults.memory_limit'
    $cpu     = Get-Setting '.defaults.cpu_limit'
    $port    = Get-Setting '.integrations.mcp_port'

    $ctypeLabel = switch ($ctype) {
        "cli" { "Minimal CLI" }
        "gui" { "GUI Desktop" }
        default { "Ask each time" }
    }

    Write-Host ""
    Write-Host "--- Preferences ---" -ForegroundColor Cyan
    Write-Host "  [1] Auto-backup:       $autoBk"
    Write-Host "  [2] Default container: $ctypeLabel"
    Write-Host "  [3] Memory limit:      $mem"
    Write-Host "  [4] CPU limit:         $cpu"
    Write-Host "  [5] MCP port:          $port"
    Write-Host "  [B] Back"
}

function Show-PreferencesMenu {
    Ensure-ConfigFile

    while ($true) {
        _Show-PreferencesDisplay

        $choice = Read-Host "`nPreference"

        switch ($choice.ToUpper()) {
            "1" {
                $cur = Get-SettingBool '.backup.auto_backup'
                $newVal = if ($cur -eq "true") { $false } else { $true }
                Set-Setting '.backup.auto_backup' $newVal
                Write-Host "[OK] Auto-backup: $($newVal.ToString().ToLower())" -ForegroundColor Green
            }
            "2" {
                $cur = Get-Setting '.defaults.container_type'
                $newVal = switch ($cur) {
                    "cli" { "gui" }
                    "gui" { "cli" }
                    default { "cli" }
                }
                Set-Setting '.defaults.container_type' $newVal
                Write-Host "[OK] Default container type: $newVal" -ForegroundColor Green
            }
            "3" {
                $cur = Get-Setting '.defaults.memory_limit'
                $input = Read-Host "Memory limit [$cur]"
                if ([string]::IsNullOrWhiteSpace($input)) { $input = $cur }
                if ($input -notmatch '^[0-9]+[mgkMGK]?$') {
                    Write-Host "[!] Memory must match Docker format (e.g. 2g, 512m, 1024k, or bytes)." -ForegroundColor Red
                } else {
                    Set-Setting '.defaults.memory_limit' $input
                    Write-Host "[OK] Memory limit: $input" -ForegroundColor Green
                }
            }
            "4" {
                $cur = Get-Setting '.defaults.cpu_limit'
                $input = Read-Host "CPU limit [$cur]"
                if ([string]::IsNullOrWhiteSpace($input)) { $input = $cur }
                if ($input -notmatch '^[0-9]+(\.[0-9]+)?$') {
                    Write-Host "[!] CPU limit must be a positive number (e.g. 2 or 0.5)." -ForegroundColor Red
                } else {
                    # Store as number
                    $numVal = [double]$input
                    Set-Setting '.defaults.cpu_limit' $numVal
                    Write-Host "[OK] CPU limit: $input" -ForegroundColor Green
                }
            }
            "5" {
                $cur = Get-Setting '.integrations.mcp_port'
                $input = Read-Host "MCP port [$cur]"
                if ([string]::IsNullOrWhiteSpace($input)) { $input = $cur }
                if ($input -notmatch '^[0-9]+$' -or [int]$input -lt 1024 -or [int]$input -gt 65535) {
                    Write-Host "[!] Port must be a number between 1024 and 65535." -ForegroundColor Red
                } else {
                    Set-Setting '.integrations.mcp_port' ([int]$input)
                    Write-Host "[OK] MCP port: $input" -ForegroundColor Green
                }
            }
            "B" { return }
            default { Write-Host "Invalid choice." -ForegroundColor Red }
        }
    }
}

# ===========================================================================
# Env / credentials
# ===========================================================================

function Ensure-EnvFile {
    if (-not (Test-Path $Script:EnvFile)) {
        $template = "# Claude Sandbox Manager - Credentials`n" +
            "# These are injected into containers at runtime (never baked into images).`n" +
            "# Fill in your keys and save this file.`n`n" +
            "ANTHROPIC_API_KEY=`n" +
            "GITHUB_TOKEN=`n"
        $template | Set-Content $Script:EnvFile -Encoding UTF8 -NoNewline
        Write-Host "[!] Created .env template at $Script:EnvFile - add your API keys" -ForegroundColor Yellow
    }
}

function Get-EnvCredentials {
    $creds = @{}
    if (-not (Test-Path $Script:EnvFile)) {
        return $creds
    }
    foreach ($line in Get-Content $Script:EnvFile) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $key = $Matches[1]
            $val = $Matches[2].Trim()
            # Strip surrounding quotes
            if (($val.StartsWith('"') -and $val.EndsWith('"')) -or
                ($val.StartsWith("'") -and $val.EndsWith("'"))) {
                $val = $val.Substring(1, $val.Length - 2)
            }
            if ($val -ne "") {
                $creds[$key] = $val
            }
        }
    }
    return $creds
}

function Get-DockerEnvFlags {
    $creds = Get-EnvCredentials
    $flags = @()
    foreach ($key in @("ANTHROPIC_API_KEY", "GITHUB_TOKEN")) {
        if ($creds.ContainsKey($key)) {
            $flags += "-e"
            $flags += "$key=$($creds[$key])"
        } else {
            Write-Host "[!] Credential '$key' not set in .env" -ForegroundColor Yellow
        }
    }
    return $flags
}

# ===========================================================================
# Container status
# ===========================================================================

function Get-ContainerStatus($Name) {
    $containerName = Get-ContainerName $Name
    $status = docker inspect --format '{{.State.Status}}' $containerName 2>$null
    if ($LASTEXITCODE -ne 0) { return "not created" }
    return $status
}

# ===========================================================================
# Instance list display (updated for type/vnc_port awareness)
# ===========================================================================

function Show-InstanceList {
    $instances = Get-Instances
    $props = @($instances.PSObject.Properties)
    if ($props.Count -eq 0) {
        Write-Host "  (no instances registered)" -ForegroundColor Gray
        return
    }
    foreach ($prop in $props) {
        $name   = $prop.Name
        $port   = $prop.Value.port
        $type   = if ($prop.Value.PSObject.Properties["type"]) { $prop.Value.type } else { "cli" }
        $status = Get-ContainerStatus $name
        $color  = switch ($status) {
            "running" { "Green" }
            "exited"  { "Yellow" }
            default   { "Gray" }
        }
        $alias = Get-SshAlias $name

        Write-Host "  [$name]" -ForegroundColor Cyan -NoNewline
        Write-Host "  [$type]" -NoNewline

        if ($type -eq "gui" -and $prop.Value.PSObject.Properties["vnc_port"]) {
            $vncPort = $prop.Value.vnc_port
            Write-Host "  (ssh:$port vnc:$vncPort)  " -NoNewline
        } else {
            Write-Host "  (port $port)  " -NoNewline
        }

        Write-Host $status -ForegroundColor $color -NoNewline
        Write-Host "  (ssh $alias)"
    }
}

# ===========================================================================
# Instance selection
# ===========================================================================

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

# ===========================================================================
# Instance registry CRUD (updated for type, vnc_port, mcp_enabled, remote_control)
# ===========================================================================

function Register-Instance($Name, $Type = "cli") {
    $instances = Get-Instances
    if ($instances.PSObject.Properties[$Name]) {
        return $instances.PSObject.Properties[$Name].Value.port
    }
    $port = Get-NextFreePort

    $record = [PSCustomObject]@{
        port           = $port
        type           = $Type
        mcp_enabled    = $true
        remote_control = $false
    }

    if ($Type -eq "gui") {
        $vncPort = Get-NextFreeVncPort
        $record | Add-Member -NotePropertyName "vnc_port" -NotePropertyValue $vncPort
    }

    $instances | Add-Member -NotePropertyName $Name -NotePropertyValue $record
    Save-Instances $instances
    Write-Host "Registered instance '$Name' ($Type) on port $port" -ForegroundColor Green
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

function Get-InstanceType($Name) {
    $instances = Get-Instances
    $prop = $instances.PSObject.Properties[$Name]
    if (-not $prop) { return "cli" }
    if ($prop.Value.PSObject.Properties["type"]) { return $prop.Value.type }
    return "cli"
}

function Get-InstanceVncPort($Name) {
    $instances = Get-Instances
    $prop = $instances.PSObject.Properties[$Name]
    if (-not $prop) { return $null }
    if ($prop.Value.PSObject.Properties["vnc_port"]) { return $prop.Value.vnc_port }
    return $null
}

# ===========================================================================
# SSH key management
# ===========================================================================

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
    $srcKeyPath = "$(Get-SshDir $Name)\id_claude"
    $alias = Get-SshAlias $Name

    if (-not (Test-Path "$env:USERPROFILE\.ssh")) {
        New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" | Out-Null
    }

    # Copy key to ~/.ssh/claude-<alias>/ so the path has no spaces
    # (Windows OpenSSH cannot handle spaces in IdentityFile paths)
    $safeKeyDir = "$env:USERPROFILE\.ssh\$alias"
    if (-not (Test-Path $safeKeyDir)) {
        New-Item -ItemType Directory -Path $safeKeyDir | Out-Null
    }
    $safeKeyPath = "$safeKeyDir\id_claude"
    # Reset permissions before copy - previous icacls may have set read-only
    if (Test-Path $safeKeyPath) {
        icacls $safeKeyPath /grant "${env:USERNAME}:(F)" 2>$null | Out-Null
    }
    Copy-Item -Force $srcKeyPath $safeKeyPath
    # Lock down: remove inheritance, grant read-only (required by OpenSSH)
    icacls $safeKeyPath /inheritance:r /grant:r "${env:USERNAME}:(R)" 2>$null | Out-Null

    $hostBlock = @"

Host $alias
  HostName localhost
  Port $Port
  User claude
  IdentityFile $safeKeyPath
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
"@

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
}

# ===========================================================================
# Backup / restore (port from lib/backup.sh)
# ===========================================================================

function Invoke-Backup($Name) {
    $containerName = Get-ContainerName $Name
    $status = Get-ContainerStatus $Name
    if ($status -eq "not created") {
        Write-Host "[!] Instance '$Name' has no container to back up (not created)." -ForegroundColor Yellow
        return $false
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
    $backupRoot = Get-BackupDir $Name
    $backupDir  = "$backupRoot\$timestamp"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    # Step 1: docker commit
    $imageTag = "$containerName-backup-$timestamp"
    Write-Host "Committing container $containerName..." -ForegroundColor Yellow
    docker commit $containerName $imageTag
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[X] docker commit failed." -ForegroundColor Red
        return $false
    }

    # Step 2: docker save | gzip
    Write-Host "Saving image to $backupDir\image.tar.gz..." -ForegroundColor Yellow
    docker save $imageTag | & { param($input) [System.IO.Compression.GZipStream]::new(
        [System.IO.File]::Create("$backupDir\image.tar.gz"),
        [System.IO.Compression.CompressionMode]::Compress) } 2>$null

    # Simpler cross-platform approach: docker save then compress with .NET
    # (docker save | gzip is not available in all Windows environments, use PowerShell)
    docker save $imageTag -o "$backupDir\image.tar"
    if ($LASTEXITCODE -eq 0) {
        # Compress using PowerShell (available on Windows 10+)
        $inputPath  = "$backupDir\image.tar"
        $outputPath = "$backupDir\image.tar.gz"
        try {
            $inputStream  = [System.IO.File]::OpenRead($inputPath)
            $outputStream = [System.IO.File]::Create($outputPath)
            $gzipStream   = [System.IO.Compression.GZipStream]::new($outputStream, [System.IO.Compression.CompressionMode]::Compress)
            $inputStream.CopyTo($gzipStream)
            $gzipStream.Close()
            $outputStream.Close()
            $inputStream.Close()
            Remove-Item $inputPath -Force
            Write-Host "[OK] Image saved to image.tar.gz" -ForegroundColor Green
        } catch {
            Write-Host "[!] Compression failed, keeping image.tar: $_" -ForegroundColor Yellow
            if (Test-Path $outputPath) { Remove-Item $outputPath -Force }
        }
    }

    # Step 3: archive workspace
    $wsDir = Get-WorkspaceDir $Name
    if (Test-Path $wsDir) {
        Write-Host "Archiving workspace to $backupDir\workspace.tar.gz..." -ForegroundColor Yellow
        & tar -czf "$backupDir\workspace.tar.gz" -C $wsDir . 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] workspace archive failed (tar may not be available)." -ForegroundColor Yellow
        }
    }

    # Step 4: write metadata.json
    $instances = Get-Instances
    $instProp  = $instances.PSObject.Properties[$Name]
    $instPort  = if ($instProp) { $instProp.Value.port } else { 0 }
    $instType  = if ($instProp -and $instProp.Value.PSObject.Properties["type"]) { $instProp.Value.type } else { "cli" }

    $metadata = [PSCustomObject]@{
        imagetag  = $imageTag
        instance  = $Name
        port      = $instPort
        type      = $instType
        timestamp = $timestamp
    }
    $metaTmp = "$backupDir\metadata.json.tmp"
    $metadata | ConvertTo-Json -Depth 5 | Set-Content $metaTmp -Encoding UTF8
    Move-Item -Force $metaTmp "$backupDir\metadata.json"

    Write-Host "[OK] Backup complete: $backupDir" -ForegroundColor Green
    return $true
}

function Get-BackupList($Name) {
    $backupRoot = Get-BackupDir $Name
    if (-not (Test-Path $backupRoot)) {
        Write-Host "[!] No backups found for instance '$Name'." -ForegroundColor Yellow
        return @()
    }

    $dirs = @(Get-ChildItem $backupRoot -Directory | Sort-Object Name -Descending)
    if ($dirs.Count -eq 0) {
        Write-Host "[!] No backups found for instance '$Name'." -ForegroundColor Yellow
        return @()
    }

    Write-Host "`nAvailable backups for '$Name':" -ForegroundColor Cyan
    $i = 1
    foreach ($dir in $dirs) {
        $size = try { "{0:N1} MB" -f ((Get-ChildItem $dir.FullName -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB) } catch { "?" }
        Write-Host "  $i) $($dir.Name) ($size)"
        $i++
    }
    return @($dirs | ForEach-Object { $_.FullName })
}

function Invoke-Restore($Name, $BackupDir) {
    $containerName = Get-ContainerName $Name
    $wsDir = Get-WorkspaceDir $Name

    # Read metadata
    $metaPath = "$BackupDir\metadata.json"
    if (-not (Test-Path $metaPath)) {
        Write-Host "[X] No metadata.json found in backup." -ForegroundColor Red
        return $false
    }
    $meta     = Get-Content $metaPath -Raw | ConvertFrom-Json
    $imageTag = $meta.imagetag

    Write-Host "Restoring instance '$Name' from backup..." -ForegroundColor Yellow

    # Step 1: stop and remove existing container
    Write-Host "Stopping existing container..." -ForegroundColor Yellow
    docker stop $containerName 2>$null | Out-Null
    docker rm $containerName 2>$null | Out-Null

    # Step 2: load backup image
    Write-Host "Loading backup image..." -ForegroundColor Yellow
    $imageTarGz = "$BackupDir\image.tar.gz"
    $imageTar   = "$BackupDir\image.tar"

    if (Test-Path $imageTarGz) {
        # Decompress then load
        $tmpTar = "$env:TEMP\csm-restore-$Name.tar"
        try {
            $inputStream  = [System.IO.File]::OpenRead($imageTarGz)
            $outputStream = [System.IO.File]::Create($tmpTar)
            $gzipStream   = [System.IO.Compression.GZipStream]::new($inputStream, [System.IO.Compression.CompressionMode]::Decompress)
            $gzipStream.CopyTo($outputStream)
            $gzipStream.Close()
            $outputStream.Close()
            $inputStream.Close()
            docker load -i $tmpTar
            Remove-Item $tmpTar -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Host "[X] Failed to decompress image: $_" -ForegroundColor Red
            return $false
        }
    } elseif (Test-Path $imageTar) {
        docker load -i $imageTar
    } else {
        Write-Host "[X] No image.tar.gz or image.tar found in backup." -ForegroundColor Red
        return $false
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[X] docker load failed." -ForegroundColor Red
        return $false
    }

    # Step 3: restore workspace
    Write-Host "Restoring workspace..." -ForegroundColor Yellow
    if (-not (Test-Path $wsDir)) { New-Item -ItemType Directory -Path $wsDir | Out-Null }
    $wsTarGz = "$BackupDir\workspace.tar.gz"
    if (Test-Path $wsTarGz) {
        Get-ChildItem $wsDir -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        & tar -xzf $wsTarGz -C $wsDir 2>$null
    }

    # Step 4: re-run container using Start-SandboxInstance logic with backup image tag
    $instances = Get-Instances
    $instProp  = $instances.PSObject.Properties[$Name]
    $port      = if ($instProp) { $instProp.Value.port } else { Get-NextFreePort }
    $type      = if ($instProp -and $instProp.Value.PSObject.Properties["type"]) { $instProp.Value.type } else { "cli" }
    $vncPort   = if ($instProp -and $instProp.Value.PSObject.Properties["vnc_port"]) { $instProp.Value.vnc_port } else { $null }

    # Check port availability before attempting docker run
    $port = Resolve-Port $Name $port
    if ($type -eq "gui" -and $vncPort) {
        $vncPort = Resolve-VncPort $Name $vncPort
    }

    $memLimit = Get-Setting '.defaults.memory_limit'
    if (-not $memLimit) { $memLimit = "2g" }
    $cpuLimit = Get-Setting '.defaults.cpu_limit'
    if (-not $cpuLimit) { $cpuLimit = "2" }

    Ensure-EnvFile
    $envFlags = Get-DockerEnvFlags

    $runArgs = @("run", "-d", "--name", $containerName,
        "-p", "127.0.0.1:${port}:22",
        "-v", "$(($wsDir -replace '\\','/')):/home/claude/workspace",
        "-w", "/home/claude/workspace",
        "--memory=$memLimit",
        "--cpus=$cpuLimit",
        "--security-opt=no-new-privileges",
        "--cap-drop=MKNOD",
        "--cap-drop=AUDIT_WRITE",
        "--cap-drop=SETFCAP",
        "--cap-drop=SETPCAP",
        "--cap-drop=NET_BIND_SERVICE",
        "--cap-drop=SYS_CHROOT",
        "--cap-drop=FSETID",
        "--restart", "unless-stopped")

    if ($type -eq "gui" -and $vncPort) {
        $runArgs += "-p"
        $runArgs += "127.0.0.1:${vncPort}:6080"
        $runArgs += "--shm-size=512m"
    }

    $runArgs += $envFlags
    $runArgs += $imageTag

    & docker @runArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[X] Failed to start restored container." -ForegroundColor Red
        return $false
    }

    Write-SshConfig $Name $port
    Write-Host "[OK] Restore complete. Instance '$Name' running from backup." -ForegroundColor Green
    return $true
}

# ===========================================================================
# Start sandbox instance (updated: security hardening, type-aware build/run)
# ===========================================================================

function Start-SandboxInstance($Name) {
    $port = Register-Instance $Name
    $port = Resolve-Port $Name $port

    $type    = Get-InstanceType $Name
    $vncPort = Get-InstanceVncPort $Name
    if ($type -eq "gui" -and $vncPort) {
        $vncPort = Resolve-VncPort $Name $vncPort
    }

    Ensure-SshKeys $Name
    Ensure-Workspace $Name
    Stage-SshKeys $Name

    $containerName = Get-ContainerName $Name
    $imageName     = "claude-sandbox-$Name-$type"
    $wsDir         = (Get-WorkspaceDir $Name) -replace '\\', '/'

    # Auto-backup before rebuilding if enabled and container exists
    $autoBackup = Get-SettingBool '.backup.auto_backup'
    if ($autoBackup -eq "true") {
        $existing = Get-ContainerStatus $Name
        if ($existing -eq "running" -or $existing -eq "exited") {
            Write-Host "Auto-backup: creating backup before start..." -ForegroundColor Yellow
            Invoke-Backup $Name | Out-Null
        }
    }

    # Build image with --target flag for multi-stage Dockerfile
    docker build -t $imageName --target $type -f "$Script:Root\scripts\Dockerfile" "$Script:Root"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[X] Docker build failed." -ForegroundColor Red
        return $false
    }

    # Stop and remove existing container if present
    docker stop $containerName 2>$null | Out-Null
    docker rm $containerName 2>$null | Out-Null

    # Load credentials from .env
    Ensure-EnvFile
    $envFlags = Get-DockerEnvFlags

    # Read resource limits from config
    $memLimit = Get-Setting '.defaults.memory_limit'
    if (-not $memLimit) { $memLimit = "2g" }
    $cpuLimit = Get-Setting '.defaults.cpu_limit'
    if (-not $cpuLimit) { $cpuLimit = "2" }

    # Build run args with security hardening (port from lib/docker.sh)
    $runArgs = @("run", "-d", "--name", $containerName,
        "-p", "127.0.0.1:${port}:22",
        "-v", "${wsDir}:/home/claude/workspace",
        "-w", "/home/claude/workspace",
        "--memory=$memLimit",
        "--cpus=$cpuLimit",
        "--security-opt=no-new-privileges",
        "--cap-drop=MKNOD",
        "--cap-drop=AUDIT_WRITE",
        "--cap-drop=SETFCAP",
        "--cap-drop=SETPCAP",
        "--cap-drop=NET_BIND_SERVICE",
        "--cap-drop=SYS_CHROOT",
        "--cap-drop=FSETID",
        "--restart", "unless-stopped")

    # GUI-specific: VNC port and shared memory
    if ($type -eq "gui" -and $vncPort) {
        $runArgs += "-p"
        $runArgs += "127.0.0.1:${vncPort}:6080"
        $runArgs += "--shm-size=512m"
    }

    $runArgs += $envFlags
    $runArgs += $imageName

    & docker @runArgs

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

# ===========================================================================
# Migration helpers
# ===========================================================================

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
