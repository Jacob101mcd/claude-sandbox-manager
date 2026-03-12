@echo off
echo =============================================
echo Claude Sandbox Manager
echo =============================================
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File ".\scripts\claude-manager.ps1"
pause
