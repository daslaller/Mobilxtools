# Batch Script (Save as SystemCheck.bat)
@echo off
setlocal enabledelayedexpansion

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Error: Please run as administrator
    pause
    exit /b 1
)

:: Create log file
set logfile=SystemCheck_Log.txt
echo System Check Started at %date% %time% > %logfile%
echo ------------------------ >> %logfile%

:: Function to log messages
call :log "Starting System Diagnostics..."

:: [Previous checks remain the same...]
:: Check disk space
call :log "Checking disk space..."
wmic logicaldisk get deviceid,size,freespace

:: Run System File Checker
call :log "Running System File Checker..."
sfc /scannow

:: Run DISM checks
call :log "Running DISM health check..."
DISM /Online /Cleanup-Image /CheckHealth
call :log "Running DISM scan..."
DISM /Online /Cleanup-Image /ScanHealth
call :log "Running DISM repair..."
DISM /Online /Cleanup-Image /RestoreHealth

:: Check disk errors
call :log "Running chkdsk..."
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist %%D:\ (
        call :log "Checking drive %%D..."
        chkdsk %%D: /f
    )
)

:: Check Windows Update service
call :log "Checking Windows Update service..."
sc query wuauserv | find "RUNNING"
if errorlevel 1 (
    call :log "Starting Windows Update service..."
    net start wuauserv
)

:: Run Windows Memory Diagnostic
call :log "Scheduling Windows Memory Diagnostic..."
mdsched.exe

call :log "Basic system check complete."

:: Ask for extended checks
set /p response="Would you like to run extended checks using additional tools? (Y/N) "
if /i "%response%"=="Y" (
    call :extended_checks
)

call :log "All checks complete. Please check the log file for details."
pause
goto :eof

:extended_checks
call :log "Starting Extended Checks..."

:: Check/create tools directory
if not exist "tools" mkdir tools

:: Check internet connection
ping 8.8.8.8 -n 1 > nul
if %errorLevel% equ 0 (
    call :log "Internet connection available. Downloading tools..."
    
    :: Download CrystalDiskInfo
    if not exist "tools\CrystalDiskInfo" (
        call :log "Downloading CrystalDiskInfo..."
        powershell -Command "Invoke-WebRequest -Uri 'https://osdn.net/dl/crystaldiskinfo/CrystalDiskInfo8_17_11.zip' -OutFile 'tools\CrystalDiskInfo.zip'"
        powershell -Command "Expand-Archive 'tools\CrystalDiskInfo.zip' -DestinationPath 'tools\CrystalDiskInfo'"
    )
    start /wait tools\CrystalDiskInfo\DiskInfo64.exe
    
    :: Download other tools similarly...
) else (
    call :log "No internet connection. Using local tools only..."
)

:: Run any existing tools in the tools directory
for /r "tools" %%F in (*.exe) do (
    call :log "Running %%~nxF..."
    start /wait "%%F"
)

call :log "Extended checks complete"
goto :eof

:log
echo [%date% %time%] %~1
echo [%date% %time%] %~1 >> %logfile%
goto :eof