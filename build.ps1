<#
.SYNOPSIS
    Build script for the DelSafe compiler (delsafec) on Windows via PowerShell.
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  DelSafe Compiler (delsafec) - PowerShell Build Script" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# Locate FPC
$fpcPath = Get-Command "fpc" -ErrorAction SilentlyContinue

if (-not $fpcPath) {
    $commonPaths = @(
        "C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe",
        "C:\lazarus\fpc\3.2.0\bin\x86_64-win64\fpc.exe",
        "C:\fpc\3.2.2\bin\x86_64-win64\fpc.exe",
        "C:\fpc\3.2.2\bin\i386-win32\fpc.exe",
        "C:\msys64\ucrt64\bin\fpc.exe"
    )

    foreach ($p in $commonPaths) {
        if (Test-Path $p) {
            $dir = Split-Path $p
            $env:PATH = "$dir;" + $env:PATH
            Write-Host "[*] Found FPC at: $dir" -ForegroundColor Yellow
            $fpcPath = Get-Command "fpc" -ErrorAction SilentlyContinue
            break
        }
    }
}

if (-not $fpcPath) {
    Write-Host "[ERROR] Free Pascal Compiler (fpc) was not found in PATH or standard installation paths." -ForegroundColor Red
    Write-Host "Please install Free Pascal from https://www.freepascal.org/ and ensure fpc is on your PATH."
    exit 1
}

# Ensure directories exist
if (-not (Test-Path "bin")) { New-Item -ItemType Directory -Path "bin" | Out-Null }
if (-not (Test-Path "build")) { New-Item -ItemType Directory -Path "build" | Out-Null }

Write-Host "[*] Compiling delsafec with optimizations (-O2)..." -ForegroundColor Green
& fpc -MObjFPC -Sc -O2 -FEbin -FUbuild -Fucompiler/src compiler/delsafec.lpr

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Compilation failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`n[SUCCESS] Native compiler generated at: bin\delsafec.exe`n" -ForegroundColor Green

# Run tests
Write-Host "[*] Running diagnostic check..." -ForegroundColor Cyan
& .\bin\delsafec.exe --version
& .\bin\delsafec.exe test

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  Build complete! Run '.\bin\delsafec.exe' to get started." -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
