. "$PSScriptRoot\common.ps1"

$instances = Get-Instances
if (@($instances.PSObject.Properties).Count -eq 0) {
    Write-Host "No instances found. Run claude-manager.bat first." -ForegroundColor Red
    pause; exit 1
}

$name = Select-Instance "Select instance to connect to:"
if (-not $name) { pause; exit 1 }

$alias = Get-SshAlias $name
Write-Host "Connecting to '$name' via ssh $alias..." -ForegroundColor Green
# Use Windows OpenSSH directly (Git's ssh ignores %USERPROFILE%\.ssh\config)
$sshExe = "$env:SystemRoot\System32\OpenSSH\ssh.exe"
if (-not (Test-Path $sshExe)) { $sshExe = "ssh" }
& $sshExe -t $alias "cd workspace && exec `$SHELL"
