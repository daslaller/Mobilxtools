# Enable error handling
$ErrorActionPreference = "Stop"

# Load signatures from JSON
Write-Host "Loading signatures..."
$signaturesJson = Get-Content "signatures.json" | ConvertFrom-Json

# Prepare a hashtable to store signatures
$signatures = @{}
foreach ($property in $signaturesJson.PSObject.Properties) {
    $fileType = $property.Name
    $values = $property.Value -split ',\s*' | ForEach-Object { $_ -replace '\s', '' }
    foreach ($signature in $values) {
        $signatures[$signature] = @{ "Type" = $fileType; "IsMedia" = ($fileType -match "^(jpg|jpeg|png|gif|bmp|mp4|avi|mov|wmv|flv|webm|mkv)$") }
    }
}
Write-Host "Loaded $($signatures.Count) signatures."

# Prompt for scan type
do {
    Clear-Host
    $scanType = Read-Host "What type of files do you want to identify?`n1. Media files only (images/videos)`n2. All supported file types"
} while ($scanType -ne "1" -and $scanType -ne "2")

# Prompt for recursive search
do {
    Clear-Host
    $recursive = Read-Host "Do you want to search recursively?`n1. Yes`n2. No"
} while ($recursive -ne "1" -and $recursive -ne "2")

# Prompt for input directory
do {
    Clear-Host
    $inputDir = Read-Host "Enter input directory path"
} while (-Not (Test-Path $inputDir))

# Prompt for output directory
do {
    Clear-Host
    $outputDir = Read-Host "Enter output directory path"
    if (-Not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }
} while (-Not (Test-Path $outputDir))

# Gather files
if ($recursive -eq "1") {
    $files = Get-ChildItem -Path $inputDir -Recurse -File
} else {
    $files = Get-ChildItem -Path $inputDir -File
}
$totalFiles = $files.Count
$processedFiles = 0
$lastUpdate = Get-Date

# Create log file
$logFile = "$outputDir\scan_results.txt"
"File Scan Results`nScan started at: $(Get-Date) `n" | Out-File -FilePath $logFile

# Determine max signature length in bytes
$maxSignatureLength = ($signatures.Keys | ForEach-Object { ($_ -replace '\s', '').Length / 2 } | Measure-Object -Maximum).Maximum

# Process files
foreach ($file in $files) {
    $processedFiles++
    $filePath = $file.FullName
    $fileName = $file.Name

    # Read first N bytes (max signature length)
    $fileHeader = -join ((Get-Content -Path $filePath -Encoding Byte -TotalCount $maxSignatureLength | ForEach-Object { "{0:X2}" -f $_ }) -join "")

    if ($null -eq $fileHeader -or $fileHeader -eq "") {
        "[$(Get-Date)] ERROR reading ${fileName}" | Out-File -FilePath $logFile -Append
        continue
    }

    $found = $false
    foreach ($signature in $signatures.Keys) {
        $cleanSignature = $signature -replace '\s', ''
        if ($scanType -eq "1" -and -not $signatures[$signature].IsMedia) {
            continue
        }
        if ($fileHeader.StartsWith($cleanSignature)) {
            $fileExtension = $signatures[$signature].Type.ToLower()
            "[$(Get-Date)] ${fileName}: $fileExtension file" | Out-File -FilePath $logFile -Append
            Copy-Item $filePath "$outputDir\$fileName.$fileExtension"
            $found = $true
            break
        }
    }
    if (-not $found -and $scanType -eq "2") {
        "[$(Get-Date)] ${fileName}: Unknown file type" | Out-File -FilePath $logFile -Append
    }
    
    # Batch progress update every second
    if ((Get-Date) -gt $lastUpdate.AddSeconds(1)) {
        $progress = [math]::Round(($processedFiles / $totalFiles) * 100, 2)
        Clear-Host
        Write-Host "Processing file $processedFiles of $totalFiles"
        Write-Host "Current file: $fileName"
        Write-Host "Progress: [$("=" * ($progress / 2))$("." * (50 - ($progress / 2)))] $progress%"
        $lastUpdate = Get-Date
    }
}

Write-Host "Scan completed! Results saved to: $logFile"
Pause
