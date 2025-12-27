# Script for checking Android device connection
# Usage: .\scripts\check_device.ps1

Write-Host "=== Checking Android device connection ===" -ForegroundColor Cyan
Write-Host ""

# Check if adb is available
$adbPath = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adbPath) {
    Write-Host "ERROR: adb not found in PATH!" -ForegroundColor Red
    Write-Host "Make sure Android SDK Platform Tools are installed." -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] adb found: $($adbPath.Source)" -ForegroundColor Green
Write-Host ""

# Check connected devices
Write-Host "Checking connected devices..." -ForegroundColor Cyan
$devices = adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\t' }

if ($devices.Count -eq 0) {
    Write-Host "ERROR: No devices found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Make sure:" -ForegroundColor Yellow
    Write-Host "  1. Device is connected via USB" -ForegroundColor Yellow
    Write-Host "  2. USB debugging is enabled (Settings > Developer Options > USB Debugging)" -ForegroundColor Yellow
    Write-Host "  3. Debugging is allowed on computer (if prompt appeared)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Try running: adb devices" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Found devices: $($devices.Count)" -ForegroundColor Green
Write-Host ""

# List devices
Write-Host "Connected devices:" -ForegroundColor Cyan
foreach ($device in $devices) {
    $parts = $device -split '\t'
    $deviceId = $parts[0]
    $status = $parts[1]
    
    if ($status -eq "device") {
        Write-Host "  [OK] $deviceId - ready for debugging" -ForegroundColor Green
        
        # Get device info
        $model = adb -s $deviceId shell getprop ro.product.model 2>$null
        $androidVersion = adb -s $deviceId shell getprop ro.build.version.release 2>$null
        Write-Host "    Model: $model" -ForegroundColor Gray
        Write-Host "    Android: $androidVersion" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] $deviceId - $status" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Check Flutter
Write-Host "Checking Flutter..." -ForegroundColor Cyan
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterPath) {
    Write-Host "ERROR: flutter not found in PATH!" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Flutter found: $($flutterPath.Source)" -ForegroundColor Green
Write-Host ""

# Check devices via Flutter
Write-Host "Devices detected by Flutter:" -ForegroundColor Cyan
flutter devices
Write-Host ""

Write-Host "=== Ready for debugging! ===" -ForegroundColor Green
Write-Host ""
Write-Host "To start debugging:" -ForegroundColor Cyan
Write-Host "  1. Open VS Code" -ForegroundColor Yellow
Write-Host "  2. Press F5 or select 'Run > Start Debugging'" -ForegroundColor Yellow
Write-Host "  3. Select configuration 'RareBooks Mobile (Debug)'" -ForegroundColor Yellow
Write-Host ""

