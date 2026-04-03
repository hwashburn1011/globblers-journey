# ============================================
# GLOBBLER'S JOURNEY — Export Build Script (PowerShell)
# ============================================
# Because even rogue AIs need a proper release pipeline.
#
# Usage:
#   .\export_game.ps1                      # Build all platforms
#   .\export_game.ps1 -Platform windows    # Windows only
#   .\export_game.ps1 -Platform linux      # Linux only
#   .\export_game.ps1 -Release             # Release mode (no debug symbols)
#
# Prerequisites:
#   - Godot 4.4+ installed and in PATH (or set $env:GODOT_PATH)
#   - Export templates installed (Editor > Manage Export Templates > Download)
# ============================================

param(
    [ValidateSet("all", "windows", "linux")]
    [string]$Platform = "all",
    [switch]$Release
)

$ErrorActionPreference = "Stop"

# -- Config --
$GodotCmd = if ($env:GODOT_PATH) { $env:GODOT_PATH } else { "godot" }
$ProjectDir = $PSScriptRoot
$BuildDir = Join-Path $ProjectDir "build"
$BuildMode = if ($Release) { "release" } else { "debug" }

# -- Determine platforms --
$Platforms = @()
if ($Platform -eq "all") {
    $Platforms = @("windows", "linux")
} else {
    $Platforms = @($Platform)
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  GLOBBLER'S JOURNEY - Export Build" -ForegroundColor Green
Write-Host "  Mode: $BuildMode" -ForegroundColor Green
Write-Host "  Platforms: $($Platforms -join ', ')" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# -- Verify Godot --
try {
    $ver = & $GodotCmd --version 2>&1 | Select-Object -First 1
    Write-Host "Godot version: $ver" -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: Godot not found. Set `$env:GODOT_PATH or add Godot to PATH." -ForegroundColor Red
    exit 1
}

# -- Import resources --
Write-Host "Importing project resources..." -ForegroundColor Cyan
& $GodotCmd --headless --import --path $ProjectDir 2>&1 | Out-Null
Write-Host "Import complete." -ForegroundColor Green

# -- Export flag --
$ExportFlag = if ($Release) { "--export-release" } else { "--export-debug" }

# -- Export each platform --
foreach ($plat in $Platforms) {
    switch ($plat) {
        "windows" {
            $Preset = "Windows Desktop"
            $Output = Join-Path $BuildDir "windows\GlobblersJourney.exe"
        }
        "linux" {
            $Preset = "Linux"
            $Output = Join-Path $BuildDir "linux\GlobblersJourney.x86_64"
        }
    }

    # Create output dir
    $outDir = Split-Path $Output -Parent
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    Write-Host ""
    Write-Host "Exporting: $Preset..." -ForegroundColor Cyan
    Write-Host "  Output: $Output" -ForegroundColor Cyan

    & $GodotCmd --headless --path $ProjectDir $ExportFlag $Preset $Output

    if (Test-Path $Output) {
        $size = (Get-Item $Output).Length / 1MB
        $sizeStr = "{0:N1} MB" -f $size
        Write-Host "  SUCCESS: $Output ($sizeStr)" -ForegroundColor Green
    } else {
        Write-Host "  FAILED: $Output not created" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Build complete! Globbler is loose." -ForegroundColor Green
Write-Host "  Output: $BuildDir\" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "To run: $BuildDir\windows\GlobblersJourney.exe" -ForegroundColor Cyan
