<#
.SYNOPSIS
    Official DelSafe Toolchain Installer for Windows.
    Installs delsafec.exe + std/ into %USERPROFILE%\.delsafe and updates user PATH.
#>

param(
    [string]$Version = "",
    [string]$Repo = $(if ($env:DELSAFE_UPGRADE_REPO) { $env:DELSAFE_UPGRADE_REPO } else { "affonsoelias/delsafe" }),
    [string]$InstallRoot = $(Join-Path $env:USERPROFILE ".delsafe"),
    [switch]$Nightly,
    [switch]$AllowUnsigned,
    [switch]$NoPathUpdate
)

$ErrorActionPreference = "Stop"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  DelSafe Official Installer (Windows)               " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$apiHeaders = @{ "User-Agent" = "DelSafe-Installer"; "Accept" = "application/vnd.github.v3+json" }
if ($Version) {
    $releaseUrl = "https://api.github.com/repos/$Repo/releases/tags/$Version"
    $release = Invoke-RestMethod -Uri $releaseUrl -Headers $apiHeaders
} elseif ($Nightly) {
    $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases?per_page=10" -Headers $apiHeaders
    $release = $releases | Where-Object { $_.prerelease -or ($_.tag_name -like "*nightly*") } | Select-Object -First 1
    if (-not $release) { $release = $releases | Select-Object -First 1 }
} else {
    $releaseUrl = "https://api.github.com/repos/$Repo/releases/latest"
    $release = Invoke-RestMethod -Uri $releaseUrl -Headers $apiHeaders
}

$asset = $release.assets | Where-Object {
    ($_.name -match "windows") -and ($_.name -match "x86_64|x64|amd64") -and ($_.name -notmatch "\.(sha256|sig|asc)$")
} | Select-Object -First 1

if (-not $asset) {
    throw "No compatible Windows x86_64 archive found in release $($release.tag_name)."
}

$sumAsset = $release.assets | Where-Object {
    $_.name -eq "$($asset.name).sha256" -or $_.name -eq "SHA256SUMS.txt"
} | Select-Object -First 1

$tmpDir = Join-Path $env:TEMP ("delsafe_install_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

try {
    $pkgPath = Join-Path $tmpDir $asset.name
    $extDir = Join-Path $tmpDir "extracted"
    Write-Host "[1/4] Downloading $($asset.name) ($($release.tag_name))..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $pkgPath -Headers $apiHeaders

    Write-Host "[2/4] Verifying SHA-256 integrity..."
    $computedHash = (Get-FileHash -Path $pkgPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sumAsset) {
        $sumText = (Invoke-WebRequest -Uri $sumAsset.browser_download_url -Headers $apiHeaders).Content
        if ($sumText.ToLowerInvariant() -notmatch [regex]::Escape($computedHash)) {
            throw "SHA-256 verification failed for $($asset.name)!"
        }
        Write-Host "      [OK] Checksum verified: $computedHash" -ForegroundColor Green
    } elseif (-not $AllowUnsigned) {
        throw "No SHA-256 checksum asset found. Pass -AllowUnsigned to override."
    }

    Write-Host "[3/4] Installing into $InstallRoot..."
    Expand-Archive -Path $pkgPath -DestinationPath $extDir -Force
    $exeSrc = Get-ChildItem -Path $extDir -Recurse -Filter "delsafec.exe" | Select-Object -First 1
    if (-not $exeSrc) { throw "delsafec.exe not found inside archive." }

    $binDest = Join-Path $InstallRoot "bin"
    $stdDest = Join-Path $InstallRoot "std"
    New-Item -ItemType Directory -Path $binDest -Force | Out-Null
    Copy-Item $exeSrc.FullName (Join-Path $binDest "delsafec.exe") -Force

    $stdSrc = Get-ChildItem -Path $extDir -Recurse -Directory -Filter "std" | Select-Object -First 1
    if ($stdSrc) {
        if (Test-Path $stdDest) { Remove-Item $stdDest -Recurse -Force }
        Copy-Item $stdSrc.FullName $stdDest -Recurse -Force
    }

    if (-not $NoPathUpdate) {
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$binDest*") {
            [Environment]::SetEnvironmentVariable("Path", "$binDest;$userPath", "User")
            $env:Path = "$binDest;$env:Path"
            Write-Host "      [OK] Added $binDest to user PATH." -ForegroundColor Green
        }
    }

    Write-Host "[4/4] Verifying installation..."
    & (Join-Path $binDest "delsafec.exe") --version
}
finally {
    Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
