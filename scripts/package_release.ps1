<#
.SYNOPSIS
    Packages a release archive of DelSafe (delsafec + std/ + SHA256SUMS.txt) on Windows.
#>

param(
    [string]$Version = "",
    [string]$OutDir = "dist",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot

try {
    if ([string]::IsNullOrWhiteSpace($Version)) {
        $incFile = Join-Path $RepoRoot "compiler\src\uDelSafeIncremental.pas"
        $match = Select-String -Path $incFile -Pattern "DELSAFE_COMPILER_VERSION\s*=\s*'([^']+)'" | Select-Object -First 1
        if ($match) {
            $Version = $match.Matches[0].Groups[1].Value
        } else {
            $Version = "0.5.0"
        }
    }

    if (-not $SkipBuild) {
        if (-not (Test-Path "bin")) { New-Item -ItemType Directory -Path "bin" | Out-Null }
        if (-not (Test-Path "build")) { New-Item -ItemType Directory -Path "build" | Out-Null }
        & fpc -MObjFPC -Sc -O2 -FEbin -FUbuild -Fucompiler/src compiler/delsafec.lpr
        if ($LASTEXITCODE -ne 0) {
            throw "FPC build failed with exit code $LASTEXITCODE"
        }
    }

    $exePath = Join-Path $RepoRoot "bin\delsafec.exe"
    if (-not (Test-Path $exePath)) {
        throw "Compiler binary not found at $exePath"
    }

    if (-not [System.IO.Path]::IsPathRooted($OutDir)) {
        $OutDirFull = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $OutDir))
    } else {
        $OutDirFull = [System.IO.Path]::GetFullPath($OutDir)
    }
    if (-not (Test-Path $OutDirFull)) { New-Item -ItemType Directory -Path $OutDirFull -Force | Out-Null }

    $Arch = "x86_64"
    $AssetBase = "delsafe-v$Version-windows-$Arch"
    $StageDir = Join-Path $OutDirFull "_stage_$AssetBase"
    if (Test-Path $StageDir) { Remove-Item $StageDir -Recurse -Force }
    New-Item -ItemType Directory -Path (Join-Path $StageDir "bin") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $StageDir "std") -Force | Out-Null

    Copy-Item $exePath (Join-Path $StageDir "bin\delsafec.exe") -Force
    Copy-Item (Join-Path $RepoRoot "std\*.dels") (Join-Path $StageDir "std") -Force
    if (Test-Path (Join-Path $RepoRoot "README.md")) {
        Copy-Item (Join-Path $RepoRoot "README.md") $StageDir -Force
    }
    if (Test-Path (Join-Path $RepoRoot "LICENSE")) {
        Copy-Item (Join-Path $RepoRoot "LICENSE") $StageDir -Force
    }

    $ArchiveName = "$AssetBase.zip"
    $ArchivePath = Join-Path $OutDirFull $ArchiveName
    if (Test-Path $ArchivePath) { Remove-Item $ArchivePath -Force }
    Compress-Archive -Path (Join-Path $StageDir "*") -DestinationPath $ArchivePath -CompressionLevel Optimal
    Remove-Item $StageDir -Recurse -Force

    $Hash = (Get-FileHash -Path $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    "$Hash  $ArchiveName" | Set-Content (Join-Path $OutDirFull "$ArchiveName.sha256") -Encoding ASCII
    "$Hash  $ArchiveName" | Set-Content (Join-Path $OutDirFull "SHA256SUMS.txt") -Encoding ASCII

    Write-Host "[OK] Packaged $ArchivePath" -ForegroundColor Green
    Write-Host "[OK] SHA-256: $Hash" -ForegroundColor Cyan
}
finally {
    Pop-Location
}
