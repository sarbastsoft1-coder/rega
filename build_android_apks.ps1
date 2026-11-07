# Build installable Android APKs for all REGA apps (downloadable apps, not website)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root "downloads\android_apks"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Get-LanIp {
    $candidates = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*' -and
            $_.PrefixOrigin -ne 'WellKnown'
        } |
        Select-Object -ExpandProperty IPAddress

    foreach ($ip in $candidates) {
        if ($ip -like '192.168.0.*') { return $ip }
    }
    foreach ($ip in $candidates) {
        if ($ip -like '192.168.*' -and $ip -notlike '192.168.58.*' -and $ip -notlike '192.168.125.*' -and $ip -notlike '192.168.56.*') {
            return $ip
        }
    }
    if ($candidates) { return $candidates[0] }
    return '127.0.0.1'
}

$lanIp = Get-LanIp
$apiHost = "http://${lanIp}:8001"
Write-Host "Building APKs with API host: $apiHost" -ForegroundColor Cyan
Write-Host "Output folder: $outDir" -ForegroundColor Cyan

$apps = @(
    @{ Name = "REGA_Customer"; Dir = "rega"; File = "rega-customer.apk" },
    @{ Name = "REGA_Vendor"; Dir = "rega_froshyar"; File = "rega-vendor.apk" },
    @{ Name = "REGA_Delivery"; Dir = "rega_delivery"; File = "rega-delivery.apk" },
    @{ Name = "REGA_Admin"; Dir = "rega_admin"; File = "rega-admin.apk" }
)

foreach ($app in $apps) {
    $appPath = Join-Path $root $app.Dir
    Write-Host ""
    Write-Host "==== Building $($app.Name) ====" -ForegroundColor Yellow
    Push-Location $appPath
    try {
        flutter pub get
        flutter build apk --release --dart-define=REGA_API_HOST=$apiHost
        $apk = Join-Path $appPath "build\app\outputs\flutter-apk\app-release.apk"
        if (-not (Test-Path $apk)) { throw "APK not found for $($app.Name)" }
        Copy-Item $apk (Join-Path $outDir $app.File) -Force
        Write-Host "OK -> downloads\android_apks\$($app.File)" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

@"
REGA Android APKs
=================
Built: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
API (PC Wi-Fi): $apiHost

Install on Android phone:
1. Copy APK files to phone (USB / WhatsApp / Google Drive)
2. Open the APK and Allow install from unknown sources
3. Keep phone + PC on same Wi-Fi
4. Start backend on PC:  cd rega_backend ; php artisan serve --host=0.0.0.0 --port=8001

Files:
- rega-customer.apk
- rega-vendor.apk
- rega-delivery.apk
- rega-admin.apk

iPhone note:
Native iPhone .ipa cannot be built on Windows. Needs a Mac + Xcode (or Codemagic).
"@ | Set-Content -Path (Join-Path $outDir "README.txt") -Encoding UTF8

Write-Host ""
Write-Host "All APKs ready in: $outDir" -ForegroundColor Green
explorer $outDir
