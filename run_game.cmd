@echo off
rem zengliang ·《星际拓荒者》重做版 · 启动
cd /d "%~dp0"
set GODOT=E:\godot\godot47\Godot_v4.7-stable_win64.exe
if not exist "%GODOT%" set GODOT=E:\godot\godot47\Godot_v4.7-stable_win64_console.exe
start "" "%GODOT%" --path "%~dp0"