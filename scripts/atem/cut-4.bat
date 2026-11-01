@echo off
echo {"program":"4"}>"%~dp0state.json"
start /b node "%~dp0atem-switch.js" cut 4
