@echo off
echo =============================================
echo Connecting to Claude Sandbox via SSH...
echo =============================================
ssh -t claude-sandbox "cd workspace && exec $SHELL"
