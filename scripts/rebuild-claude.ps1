$Root = Split-Path -Parent $PSScriptRoot
cd $Root

Write-Host "=== Rebuilding Claude Sandbox ===" -ForegroundColor Cyan

# Check Docker is running
docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[X] Docker Desktop is not running. Please start it and try again." -ForegroundColor Red
    exit 1
}

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

docker compose down
docker compose build --no-cache
docker compose up -d

Write-Host "`n[OK] Rebuild complete!" -ForegroundColor Green
docker ps --filter name=claude-sandbox
