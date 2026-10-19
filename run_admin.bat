@echo off
REM Double-click this file to open your portfolio admin page.
cd /d "%~dp0"
start "" http://127.0.0.1:5000
python admin\app.py
pause
