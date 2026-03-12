@echo off
echo =============================================
echo Rebuilding Claude Sandbox Container...
echo =============================================
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File ".\scripts\rebuild-claude.ps1"
pause
