@echo off
setlocal
set "GODOT_BIN=%~1"
if not defined GODOT_BIN if defined GODOT_EXE set "GODOT_BIN=%GODOT_EXE%"
if not defined GODOT_BIN (
  for %%G in (godot.exe godot4.exe) do (
    for /f "delims=" %%P in ('where %%G 2^>nul') do if not defined GODOT_BIN set "GODOT_BIN=%%P"
  )
)
if not defined GODOT_BIN goto missing
if not exist "%GODOT_BIN%" goto missing
start "" "%GODOT_BIN%" --editor --path "%~dp0godot"
exit /b 0

:missing
echo Godot 4.7.2 was not found.
echo Usage: %~nx0 "path\to\Godot.exe"
echo Or set GODOT_EXE to the executable path, or add godot.exe to PATH.
echo You can also import godot\project.godot from the Godot editor.
pause
exit /b 1
