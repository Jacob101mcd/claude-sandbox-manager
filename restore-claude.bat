@echo off
echo =============================================
echo Starting Claude Sandbox Restore...
echo =============================================
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File ".\scripts\restore-claude.ps1"
pause
