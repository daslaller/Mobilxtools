@echo off
setlocal enabledelayedexpansion

:: Enable ANSI escape sequences
for /f "tokens=*" %%a in ('powershell -Command "$Host.UI.RawUI.WindowSize.Width"') do set "console_width=%%a"

:: Read and parse JSON using PowerShell with proper handling of multiple signatures
for /f "tokens=* usebackq" %%a in (`powershell -Command "$json = Get-Content 'signatures.json' | ConvertFrom-Json; $count = ($json.PSObject.Properties | Measure-Object).Count; Write-Host $count; $json.PSObject.Properties | ForEach-Object { $signatures = $_.Value -split ',\s*' | ForEach-Object { $_.Trim() }; foreach ($sig in $signatures) { Write-Host ($_.Name + '=' + $sig) } }"`) do (
    if not defined totalSignatures (
        set "totalSignatures=%%a"
    ) else (
        set "%%a"
    )
)

:: User interaction for scan type
:askScanType
cls
echo What type of files do you want to identify?
echo 1. Media files only (images and videos)
echo 2. All supported file types
set /p scantype="Enter your choice (1 or 2): "
if "%scantype%" neq "1" if "%scantype%" neq "2" goto askScanType

:: Ask for recursive search
:askRecursive
cls
echo Do you want to search recursively through subdirectories?
echo 1. Yes
echo 2. No
set /p recursive="Enter your choice (1 or 2): "
if "%recursive%" neq "1" if "%recursive%" neq "2" goto askRecursive

:: Get input directory
:askInputDir
cls
echo Please enter the input directory path:
set /p inputdir="Path: "
if not exist "%inputdir%" (
    echo Directory does not exist!
    pause
    goto askInputDir
)

:: Get output directory
:askOutputDir
cls
echo Please enter the output directory path:
set /p outputdir="Path: "
if not exist "%outputdir%" (
    echo Creating output directory...
    mkdir "%outputdir%"
)

:: Count total files for progress tracking
set "totalfiles=0"
if "%recursive%"=="1" (
    for /r "%inputdir%" %%F in (*) do set /a totalfiles+=1
) else (
    for %%F in ("%inputdir%\*") do set /a totalfiles+=1
)

:: Initialize counters
set "processedfiles=0"

:: Create log file
set "logfile=%outputdir%\scan_results.txt"
echo File Scan Results > "%logfile%"
echo Scan started at: %date% %time% >> "%logfile%"
echo. >> "%logfile%"

:: Process files
if "%recursive%"=="1" (
    for /r "%inputdir%" %%F in (*) do call :processFile "%%F"
) else (
    for %%F in ("%inputdir%\*") do call :processFile "%%F"
)

echo.
echo Scan completed! Results saved to: %logfile%
pause
exit /b 0

:processFile
set /a processedfiles+=1
set "file=%~1"
set "filename=%~nx1"

:: Calculate overall progress percentage
set /a progress=processedfiles * 100 / totalfiles

:: Clear screen and print headers
cls
echo Overall Progress: [%processedfiles%/%totalfiles%] (%progress%%%^)
echo Current file: %filename%
echo.
echo Signature Progress: [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] (0%%)

:: Save cursor position
powershell -Command "$Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 3)"

:: Read file bytes using PowerShell
for /f "tokens=* usebackq" %%h in (`powershell -Command "$bytes = Get-Content -Path '%file%' -Encoding Byte -TotalCount 16 -ErrorAction SilentlyContinue; if($bytes){-join ($bytes | ForEach-Object { $_.ToString('X2') })}else{'ERROR'}"`) do (
    set "header=%%h"
)

if "%header%"=="ERROR" (
    echo [%date% %time%] ERROR reading %filename% >> "%logfile%"
    goto :eof
)

set "found=0"
set "signatureCount=0"

:: Compare with each signature based on scan type
for /f "tokens=1,2 delims==" %%i in ('set') do (
    if "%%i" neq "header" if "%%i" neq "file" if "%%i" neq "filename" if "%%i" neq "found" if "%%i" neq "processedfiles" if "%%i" neq "totalfiles" if "%%i" neq "progress" if "%%i" neq "signatureCount" if "%%i" neq "totalSignatures" if "%%i" neq "scantype" if "%%i" neq "recursive" if "%%i" neq "inputdir" if "%%i" neq "outputdir" if "%%i" neq "logfile" if "%%i" neq "console_width" (
        set /a signatureCount+=1
        set /a signatureProgress=signatureCount * 100 / totalSignatures
        
        :: Update signature progress display (overwrite the same line)
        call :drawProgress !signatureProgress! "Testing %%i signature"
        
        :: Remove spaces from signature for comparison
        set "sig=%%j"
        set "sig=!sig: =!"
        set "compareLength=!sig:~0,1!"
        set "testheader=!header:~0,%compareLength%!"
        
        if "!testheader!"=="!sig!" (
            echo [%date% %time%] %filename%: %%i file >> "%logfile%"
            copy "%file%" "%outputdir%\%%i_%filename%" > nul
            set "found=1"
        )
    )
)

if !found!==0 (
    if "%scantype%"=="2" echo [%date% %time%] %filename%: Unknown file type >> "%logfile%"
)

goto :eof

:drawProgress
set /a filled=%~1/2
set "progressbar="
set "spaces="

for /l %%i in (1,1,%filled%) do set "progressbar=!progressbar!█"
for /l %%i in (%filled%,1,50) do set "progressbar=!progressbar!░"

:: TODO, error in padright getting a negative value, i need to implement an abs function to keep it from running negative.
:: Move cursor to saved position and clear line
powershell -Command "$Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 3); Write-Host -NoNewline ('Signature Progress: [!progressbar!] (%~1%%) %~2' + ' '.PadRight($Host.UI.RawUI.WindowSize.Width - 'Signature Progress: [!progressbar!] (%~1%%) %~2'.Length +1))"

goto :eof
