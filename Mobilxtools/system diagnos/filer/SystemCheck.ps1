function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
    Add-Content -Path ".\SystemCheck_Log.txt" -Value "[$timestamp] $Message"
}

function Check-WindowsSettings {
    Write-Log "Checking Windows settings..."
    
    # Create array to store recommended changes
    $recommendedChanges = @()
    
    # Check System Restore
    $systemRestore = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
    if (-not $systemRestore) {
        $recommendedChanges += "System Restore appears to be disabled"
    }
    
    # Check UAC Settings
    $uacLevel = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue
    if ($uacLevel.ConsentPromptBehaviorAdmin -eq 0) {
        $recommendedChanges += "UAC is set very low or disabled"
    }
    
    # Check Windows Firewall Status
    $firewall = Get-NetFirewallProfile -ErrorAction SilentlyContinue
    if ($firewall | Where-Object { $_.Enabled -eq $false }) {
        $recommendedChanges += "One or more Windows Firewall profiles are disabled"
    }
    
    # Check Power Plan
    $powerPlan = Get-CimInstance -Namespace root/cimv2/power -ClassName win32_PowerPlan -ErrorAction SilentlyContinue | Where-Object { $_.IsActive -eq $true }
    if ($powerPlan.ElementName -ne "High performance") {
        $recommendedChanges += "Power Plan is not set to High Performance"
    }
    
    # If changes are recommended, ask user to apply them
    if ($recommendedChanges.Count -gt 0) {
        Write-Host "`nRecommended Windows Settings Changes:" -ForegroundColor Yellow
        $recommendedChanges | ForEach-Object { Write-Host "- $_" -ForegroundColor Yellow }
        
        $response = Read-Host "`nWould you like to apply these recommended changes? (Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            Write-Log "Applying recommended changes..."
            
            # Enable System Restore if disabled
            if (-not $systemRestore) {
                Enable-ComputerRestore -Drive "C:\"
                Write-Log "Enabled System Restore"
            }
            
            # Set UAC to normal level
            if ($uacLevel.ConsentPromptBehaviorAdmin -eq 0) {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 5
                Write-Log "Adjusted UAC settings"
            }
            
            # Enable Windows Firewall if disabled
            if ($firewall | Where-Object { $_.Enabled -eq $false }) {
                Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
                Write-Log "Enabled all Windows Firewall profiles"
            }
            
            # Set Power Plan to High Performance
            if ($powerPlan.ElementName -ne "High performance") {
                powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
                Write-Log "Set Power Plan to High Performance"
            }
            
            Write-Host "Changes applied successfully." -ForegroundColor Green
        } else {
            Write-Log "User chose not to apply recommended changes"
        }
    } else {
        Write-Host "All checked Windows settings are configured optimally." -ForegroundColor Green
        Write-Log "All Windows settings are properly configured"
    }
}

function Run-ExtendedChecks {
    Write-Log "Starting Extended Checks..."
    
    # Check if tools directory exists
    if (Test-Path ".\tools") {
        Write-Log "Found local tools directory"
    } else {
        Write-Log "Creating tools directory..."
        New-Item -ItemType Directory -Path ".\tools" | Out-Null
    }
    
    # Check internet connectivity
    if (Test-Connection 8.8.8.8 -Count 1 -Quiet) {
        Write-Log "Internet connection available. Downloading tools..."
        
        # Download and run CrystalDiskInfo (for drive health)
        if (-not (Test-Path ".\tools\CrystalDiskInfo")) {
            Write-Log "Downloading CrystalDiskInfo..."
            Invoke-WebRequest -Uri "https://osdn.net/dl/crystaldiskinfo/CrystalDiskInfo8_17_11.zip" -OutFile ".\tools\CrystalDiskInfo.zip"
            Expand-Archive ".\tools\CrystalDiskInfo.zip" -DestinationPath ".\tools\CrystalDiskInfo"
        }
        Start-Process ".\tools\CrystalDiskInfo\DiskInfo64.exe" -Wait
        
        # Download and run MemTest86 (for memory testing)
        if (-not (Test-Path ".\tools\MemTest86")) {
            Write-Log "Downloading MemTest86..."
            Invoke-WebRequest -Uri "https://www.memtest86.com/downloads/memtest86-usb.zip" -OutFile ".\tools\MemTest86.zip"
            Expand-Archive ".\tools\MemTest86.zip" -DestinationPath ".\tools\MemTest86"
        }
        
        # Download and run Prime95 (for CPU stress test)
        if (-not (Test-Path ".\tools\Prime95")) {
            Write-Log "Downloading Prime95..."
            Invoke-WebRequest -Uri "https://www.mersenne.org/download/software/v30/p95v307b9.win64.zip" -OutFile ".\tools\Prime95.zip"
            Expand-Archive ".\tools\Prime95.zip" -DestinationPath ".\tools\Prime95"
        }
    } else {
        Write-Log "No internet connection. Using local tools only..."
    }
    
    # Run local tools if available
    Get-ChildItem ".\tools" -Recurse -Include *.exe | ForEach-Object {
        Write-Log "Running $($_.Name)..."
        Start-Process $_.FullName -Wait
    }
    
    Write-Log "Extended checks complete"
}

# Main script starts here
$logPath = ".\SystemCheck_Log.txt"
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Set-Content -Path $logPath -Value "System Check Started at $date`n------------------------"

Write-Log "Starting System Diagnostics..."

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "Error: Script must be run as Administrator"
    exit 1
}

# Check and prompt for Windows Settings changes
Check-WindowsSettings

# [Previous checks remain the same...]
# Check disk space
Write-Log "Checking disk space..."
Get-Volume | ForEach-Object {
    if ($_.DriveLetter) {
        Write-Log "Drive $($_.DriveLetter): $([math]::Round($_.SizeRemaining/1GB, 2))GB free of $([math]::Round($_.Size/1GB, 2))GB"
    }
}

# Check system file integrity
Write-Log "Running System File Checker..."
Start-Process sfc.exe -ArgumentList "/scannow" -Wait -NoNewWindow

# Check and repair Windows image
Write-Log "Running DISM health check..."
Start-Process dism.exe -ArgumentList "/Online /Cleanup-Image /CheckHealth" -Wait -NoNewWindow
Write-Log "Running DISM scan..."
Start-Process dism.exe -ArgumentList "/Online /Cleanup-Image /ScanHealth" -Wait -NoNewWindow
Write-Log "Running DISM repair..."
Start-Process dism.exe -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -NoNewWindow

# Check disk errors
Write-Log "Running chkdsk..."
Get-Volume | Where-Object {$_.DriveType -eq 'Fixed'} | ForEach-Object {
    if ($_.DriveLetter) {
        Write-Log "Checking drive $($_.DriveLetter)..."
        Start-Process chkdsk.exe -ArgumentList "$($_.DriveLetter): /f" -Wait -NoNewWindow
    }
}

# Check Windows Update service
Write-Log "Checking Windows Update service..."
$wuauserv = Get-Service -Name wuauserv
if ($wuauserv.Status -ne 'Running') {
    Write-Log "Starting Windows Update service..."
    Start-Service wuauserv
}

# Run Windows Memory Diagnostic (will require reboot)
Write-Log "Scheduling Windows Memory Diagnostic..."
Start-Process mdsched.exe

Write-Log "Basic system check complete."

# Ask for extended checks
$response = Read-Host "Would you like to run extended checks using additional tools? (Y/N)"
if ($response -eq 'Y' -or $response -eq 'y') {
    Run-ExtendedChecks
}

Write-Log "All checks complete. Please check the log file for details."
pause


