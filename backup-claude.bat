@echo off
echo =============================================
echo Starting FULL Claude Sandbox Backup...
echo =============================================
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File ".\scripts\backup-claude.ps1"
pause