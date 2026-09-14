@echo off
echo {"program":"2"}>"%~dp0state.json"
start /b node "%~dp0atem-switch.js" cut 2
