@echo off
echo {"program":"1"}>"%~dp0state.json"
start /b node "%~dp0atem-switch.js" cut 1
