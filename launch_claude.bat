@echo off
cd /d "%~dp0"
echo Launching Claude CLI for Better Control...
powershell -NoExit -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; claude"
