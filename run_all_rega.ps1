# REGA Unified Ecosystem Launcher (PostgreSQL Backend + 4 Flutter Apps)
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Starting REGA Backend API (Laravel + PostgreSQL) on http://127.0.0.1:8001 ..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$root\rega_backend'; php artisan serve --host=127.0.0.1 --port=8001"

$apps = @(
    @{ Name = "REGA Admin (3 Core Parts: Vendor / Customer / Delivery)"; Dir = "rega_admin"; Port = 8080 },
    @{ Name = "REGA Froshyar (Vendor App)"; Dir = "rega_froshyar"; Port = 8081 },
    @{ Name = "REGA Customer Marketplace"; Dir = "rega"; Port = 8082 },
    @{ Name = "REGA Delivery Captain App"; Dir = "rega_delivery"; Port = 8083 }
)

foreach ($app in $apps) {
    $webDir = Join-Path $root "$($app.Dir)\build\web"
    if (-not (Test-Path $webDir)) {
        Write-Host "Building web bundle for $($app.Name) ..." -ForegroundColor Yellow
        Push-Location (Join-Path $root $app.Dir)
        flutter build web --no-pub
        Pop-Location
    }
    Write-Host "Serving $($app.Name) on http://127.0.0.1:$($app.Port) ..." -ForegroundColor Green
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$webDir'; python -m http.server $($app.Port) --bind 127.0.0.1"
}

Start-Sleep -Seconds 2
Start-Process "http://127.0.0.1:8080"
Write-Host "All REGA services are live!" -ForegroundColor Green

