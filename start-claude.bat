@echo off
echo =============================================
echo Starting Claude Sandbox Container...
echo =============================================
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File ".\scripts\start-claude.ps1"
pause