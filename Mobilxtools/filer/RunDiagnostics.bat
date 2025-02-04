@echo off
setlocal enabledelayedexpansion

cls
echo sets delayed expansion

echo Created log file
set logfile=%~dp0SystemCheck_Log.txt
echo System Check Started at %date% %time% > "%logfile%" 2>&1 || (
    echo Error: Could not create log file. Ensure the script is running with appropriate permissions. >> "%logfile%"
    pause
    exit /b 1
)
echo %logfile%
echo ------------------------ >> "%logfile%"

echo Check for admin privileges
net session >nul 2>&1
if !errorLevel! neq 0 (
    echo Error: Please run this script as administrator >> "%logfile%"
    echo Right-click the script and select "Run as administrator" >> "%logfile%"
    pause
    exit /b 1
)

echo Check PowerShell availability and execution policy
echo Checking PowerShell configuration... >> "%logfile%"

:: Check PowerShell availability with an actual command that should provide a clear success/failure status
powershell -Command "exit 0" >nul 2>&1
if !errorLevel! neq 0 (
    echo PowerShell is not available on this system. >> "%logfile%"
    echo Proceeding with Batch script only... >> "%logfile%"
    timeout /t 3
    call "%~dp0SystemCheck.bat"
    exit /b 0
)

echo PowerShell is available on this system. >> "%logfile%"

echo Check execution policy >> "%logfile%"
powershell -Command "Get-ExecutionPolicy" | find /i "RemoteSigned" > nul
if !errorLevel! neq 0 (
    echo Current PowerShell execution policy is restricted. >> "%logfile%"
    echo Changing PowerShell execution policy to RemoteSigned... >> "%logfile%"
    powershell -Command "Set-ExecutionPolicy RemoteSigned -Force" 2>> "%logfile%"
    if !errorLevel! neq 0 (
        echo Warning: Failed to change execution policy. >> "%logfile%"
        echo PowerShell script might not run properly. >> "%logfile%"
    ) else (
        echo Successfully changed execution policy to RemoteSigned. >> "%logfile%"
    )
) else (
    echo PowerShell execution policy is already correctly set. >> "%logfile%"
)

echo. >> "%logfile%"
echo System is ready for diagnostics. >> "%logfile%"
echo. >> "%logfile%"
cls
echo Please choose your diagnostic method:
echo 1) PowerShell Script [Recommended] - More detailed analysis
echo 2) Batch Script - Basic system checks
set /p choice="Enter your choice (1 or 2):"

if "!choice!"=="" (
    echo Invalid input. Please enter 1 or 2. >> "%logfile%"
    pause
    exit /b 1
)

if "!choice!"=="1" (
    echo Launching PowerShell diagnostic script... >> "%logfile%"
    timeout /t 3
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SystemCheck.ps1"
) else if "!choice!"=="2" (
    echo Launching Batch diagnostic script... >> "%logfile%"
    timeout /t 3
    call "%~dp0SystemCheck.bat"
) else (
    echo Invalid choice. Please run the script again. >> "%logfile%"
    pause
    exit /b 1
)

echo. >> "%logfile%"
echo All diagnostics completed. Please check the log file for details. >> "%logfile%"
pause
