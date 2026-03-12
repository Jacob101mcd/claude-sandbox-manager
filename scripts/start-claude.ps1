$Root = Split-Path -Parent $PSScriptRoot

Write-Host "=== Claude Sandbox Starter ===" -ForegroundColor Green

# Check Docker is running
docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[X] Docker Desktop is not running. Please start it and try again." -ForegroundColor Red
    exit 1
}

# === Ensure workspace directory exists ===
if (-not (Test-Path "$Root\workspace")) { New-Item -ItemType Directory -Path "$Root\workspace" | Out-Null }

# === Auto-generate SSH keys if missing ===
$SshDir = "$Root\ssh"
if (-not (Test-Path $SshDir)) { New-Item -ItemType Directory -Path $SshDir | Out-Null }

if (-not (Test-Path "$SshDir\id_claude")) {
    Write-Host "Generating SSH user keypair..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -f "$SshDir\id_claude" -N '""' -C "claude-sandbox"
    Write-Host "[OK] SSH user keypair generated." -ForegroundColor Green
}

if (-not (Test-Path "$SshDir\ssh_host_ed25519_key")) {
    Write-Host "Generating SSH host key..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -f "$SshDir\ssh_host_ed25519_key" -N '""' -C "claude-sandbox-host"
    Write-Host "[OK] SSH host key generated." -ForegroundColor Green
}

cd $Root
docker compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[X] docker compose up failed." -ForegroundColor Red
    exit 1
}

Write-Host "`n[OK] Claude Sandbox is now running!" -ForegroundColor Green
Write-Host "Reconnect Claude Desktop now."
docker ps --filter name=claude-sandbox

# === SSH client setup ===
$SshConfigPath = "$env:USERPROFILE\.ssh\config"
$KeyPath = "$Root\ssh\id_claude"
$HostBlock = @"

Host claude-sandbox
  HostName localhost
  Port 2222
  User claude
  IdentityFile $KeyPath
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
"@

if (-not (Test-Path "$env:USERPROFILE\.ssh")) {
    New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" | Out-Null
}

if (-not (Test-Path $SshConfigPath) -or -not (Get-Content $SshConfigPath -Raw -ErrorAction SilentlyContinue).Contains("Host claude-sandbox")) {
    Add-Content -Path $SshConfigPath -Value $HostBlock
    Write-Host "[OK] SSH config written to $SshConfigPath" -ForegroundColor Green
} else {
    Write-Host "SSH config already present, skipping." -ForegroundColor Yellow
}

icacls $KeyPath /inheritance:r /grant:r "${env:USERNAME}:(R)" | Out-Null
Write-Host "[OK] SSH key permissions fixed." -ForegroundColor Green

# === Clear stale Claude Desktop host trust (stable key = accept once, works forever) ===
$ClaudeSshConfigs = "$env:APPDATA\Claude\ssh_configs.json"
if (Test-Path $ClaudeSshConfigs) {
    $cfg = Get-Content $ClaudeSshConfigs -Raw | ConvertFrom-Json
    if ($cfg.trustedHosts -contains "claude@localhost") {
        $cfg.trustedHosts = @($cfg.trustedHosts | Where-Object { $_ -ne "claude@localhost" })
        $cfg | ConvertTo-Json -Depth 10 | Set-Content $ClaudeSshConfigs -Encoding UTF8
        Write-Host "NOTE: Cleared stale Claude Desktop host trust - you will be prompted to accept the host key once in Claude Desktop." -ForegroundColor Yellow
    }
}
