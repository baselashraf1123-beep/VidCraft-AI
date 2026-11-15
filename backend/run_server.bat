@echo off
rem One-click local server for VidCraft AI (Windows). Requires Python 3.10+ and ffmpeg in PATH.
cd /d "%~dp0"
where python >nul 2>nul || (echo Python is not installed: https://www.python.org/downloads/ ^(tick "Add to PATH"^) & pause & exit /b 1)
where ffmpeg >nul 2>nul || (echo ffmpeg is not installed: run  winget install Gyan.FFmpeg  then reopen this window & pause & exit /b 1)
if not exist .venv python -m venv .venv
call .venv\Scripts\activate.bat
pip install -q -r requirements.txt
if exist .env for /f "usebackq tokens=1,* delims==" %%a in (".env") do if not "%%b"=="" set "%%a=%%b"
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /c:"IPv4"') do (set IP=%%i & goto :go)
:go
set IP=%IP: =%
echo.
echo  Open on this PC:      http://localhost:8000
echo  Open on your phone:   http://%IP%:8000   (same Wi-Fi)
echo  App Settings URL:     http://%IP%:8000
echo.
uvicorn main:app --host 0.0.0.0 --port 8000
pause
