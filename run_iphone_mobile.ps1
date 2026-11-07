# REGA — Run all apps for iPhone / Android on the same Wi-Fi (Flutter Web)
# Native App Store iOS builds need a Mac. This script serves phone-ready web apps on your LAN IP.
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-LanIp {
    $candidates = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*' -and
            $_.PrefixOrigin -ne 'WellKnown'
        } |
        Sort-Object -Property InterfaceMetric |
        Select-Object -ExpandProperty IPAddress

    foreach ($ip in $candidates) {
        # Prefer home/office LAN ranges
        if ($ip -like '192.168.*' -or $ip -like '10.*' -or $ip -like '172.1[6-9].*' -or $ip -like '172.2*' -or $ip -like '172.3[0-1].*') {
            # Skip common Hyper-V / VMware virtual adapters when a real LAN IP exists
            if ($ip -notlike '192.168.58.*' -and $ip -notlike '192.168.56.*' -and $ip -notlike '192.168.125.*') {
                return $ip
            }
        }
    }
    if ($candidates -and $candidates.Count -gt 0) { return $candidates[0] }
    return '127.0.0.1'
}

$lanIp = Get-LanIp
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " REGA mobile (iPhone Safari) launcher" -ForegroundColor Cyan
Write-Host " PC LAN IP: $lanIp" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Backend on all interfaces
Write-Host "Starting Laravel API on http://0.0.0.0:8001 ..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$root\rega_backend'; php artisan serve --host=0.0.0.0 --port=8001"

$apps = @(
    @{ Name = "Admin"; Dir = "rega_admin"; Port = 8080 },
    @{ Name = "Vendor (Froshyar)"; Dir = "rega_froshyar"; Port = 8081 },
    @{ Name = "Customer"; Dir = "rega"; Port = 8082 },
    @{ Name = "Delivery"; Dir = "rega_delivery"; Port = 8083 }
)

foreach ($app in $apps) {
    $appDir = Join-Path $root $app.Dir
    $webDir = Join-Path $appDir "build\web"
    Write-Host "Building web (phone) for $($app.Name) ..." -ForegroundColor Yellow
    Push-Location $appDir
    flutter build web --release
    Pop-Location

    Write-Host "Serving $($app.Name) on http://${lanIp}:$($app.Port) ..." -ForegroundColor Green
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "python '$root\serve_web.py' '$webDir' $($app.Port) 0.0.0.0"
}

Write-Host ""
Write-Host "On your iPhone (same Wi-Fi as this PC), open Safari:" -ForegroundColor Green
Write-Host "  Customer : http://${lanIp}:8082" -ForegroundColor White
Write-Host "  Delivery : http://${lanIp}:8083" -ForegroundColor White
Write-Host "  Vendor   : http://${lanIp}:8081" -ForegroundColor White
Write-Host "  Admin    : http://${lanIp}:8080" -ForegroundColor White
Write-Host "  API      : http://${lanIp}:8001" -ForegroundColor White
Write-Host ""
Write-Host "Tip: Add to Home Screen from Safari Share menu for app-like use." -ForegroundColor DarkGray
Write-Host "Note: Native App Store IPA still needs a Mac + Xcode." -ForegroundColor DarkGray
Write-Host ""

Start-Sleep -Seconds 2
Start-Process "http://${lanIp}:8082"
