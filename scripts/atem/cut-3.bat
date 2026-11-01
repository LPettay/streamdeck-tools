@echo off
echo {"program":"3"}>"%~dp0state.json"
start /b node "%~dp0atem-switch.js" cut 3
