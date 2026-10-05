@echo off
setlocal
cd /d "%~dp0"
set "SKYGUARD_ENGINE=E:\godot\godot47\Godot_v4.7-stable_win64.exe"
if exist "%SKYGUARD_ENGINE%" (
  start "" "%SKYGUARD_ENGINE%" --path "%~dp0."
  exit /b
)
if exist "%~dp0build\Skyguard.exe" (
  start "" "%~dp0build\Skyguard.exe"
  exit /b
)
echo Godot 4.7 or build\Skyguard.exe is required.
pause
