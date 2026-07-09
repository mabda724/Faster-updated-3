# Faster App - Design Unification Script
# Scans for design Inconsistencies and suggests fixes
# Usage: scripts/unify_design.ps1

param(
    [string]$Path = "lib/features/*/presentation/*.dart",
    [switch]$Fix
)

$errors = @()
$warnings = @()
$stats = @{rawHexColors = 0; rawBorderRadius = 0; rawEdgeInsets = 0; rawFontSize = 0; rawIconSize = 0; rawAppBar = 0; totalFiles = 0}

function Add-Issue([string]$Type, [string]$File, [int]$Line, [string]$Message) {
    if ($Type -eq "ERROR") { $script:errors += "[$Type] $File`:$Line - $Message" }
    else { $script:warnings += "[$Type] $File`:$Line - $Message" }
}

Write-Host "Faster App Design Unification Scan" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

Get-ChildItem $Path -Recurse | Where-Object { $_.Extension -eq '.dart' } | ForEach-Object {
    $file = $_; $content = Get-Content $file.FullName -Raw; $stats.totalFiles++

    # 1. Raw hex colors
    [regex]::Matches($content, 'Color\(0xFF[0-9A-Fa-f]{6}\)') | ForEach-Object {
        $line = ($content.Substring(0, $_.Index).Split("`n").Count + 1)
        if (-not ($content.Substring([Math]::Max(0, $_.Index - 50), 100) -match 'AppTheme|ThemedColor')) {
            Add-Issue "ERROR" $file.Name $line "Raw hex color found: $($_.Value) - Use AppTheme.xxx"
            $stats.rawHexColors++
        }
    }

    # 2. Raw BorderRadius
    [regex]::Matches($content, 'BorderRadius\.circular\([0-9]+\)') | ForEach-Object {
        $line = ($content.Substring(0, $_.Index).Split("`n").Count + 1)
        if (-not ($content.Substring([Math]::Max(0, $_.Index - 100), 200) -match 'DesignTokens')) {
            Add-Issue "WARN" $file.Name $line "Raw BorderRadius found: $($_.Value) - Use DesignTokens.br*"
            $stats.rawBorderRadius++
        }
    }

    # 3. Raw EdgeInsets
    [regex]::Matches($content, 'EdgeInsets\.(all|symmetric|only)\([^)]*\)') | ForEach-Object {
        $line = ($content.Substring(0, $_.Index).Split("`n").Count + 1)
        if (-not ($content.Substring([Math]::Max(0, $_.Index - 100), 200) -match 'DesignTokens')) {
            Add-Issue "WARN" $file.Name $line "Raw EdgeInsets found - Use DesignTokens.space* or padding*"
            $stats.rawEdgeInsets++
        }
    }

    # 4. Raw fontSize without Theme
    [regex]::Matches($content, 'fontSize:\s+[0-9]+\.[0-9]*') | ForEach-Object {
        $line = ($content.Substring(0, $_.Index).Split("`n").Count + 1)
        $ctx = $content.Substring([Math]::Max(0, $_.Index - 200), 400)
        if (-not ($ctx -match 'Theme\.of\(context\)\.textTheme|DesignTokens\.text')) {
            Add-Issue "WARN" $file.Name $line "Raw fontSize found - Use Theme.of(context).textTheme/DesignTokens"
            $stats.rawFontSize++
        }
    }

    # 5. Raw AppBar
    [regex]::Matches($content, '\bAppBar\s*\(') | ForEach-Object {
        $line = ($content.Substring(0, $_.Index).Split("`n").Count + 1)
        $ctx = $content.Substring([Math]::Max(0, $_.Index - 50), 100)
        if (-not ($ctx -match 'AppAppBar|AppScreen')) {
            Add-Issue "WARN" $file.Name $line "Raw AppBar found - Use AppAppBar for consistency"
            $stats.rawAppBar++
        }
    }
}

Write-Host "`nSCAN SUMMARY" -ForegroundColor Cyan
Write-Host "Files scanned:    $($stats.totalFiles)"
Write-Host "Raw hex colors:   $($stats.rawHexColors)" -ForegroundColor $(if ($stats.rawHexColors -gt 0) {"Red"} else {"Green"})
Write-Host "Raw BorderRadius: $($stats.rawBorderRadius)" -ForegroundColor $(if ($stats.rawBorderRadius -gt 0) {"Yellow"} else {"Green"})
Write-Host "Raw EdgeInsets:   $($stats.rawEdgeInsets)" -ForegroundColor $(if ($stats.rawEdgeInsets -gt 0) {"Yellow"} else {"Green"})
Write-Host "Raw fontSize:     $($stats.rawFontSize)" -ForegroundColor $(if ($stats.rawFontSize -gt 0) {"Yellow"} else {"Green"})
Write-Host "Raw AppBar:       $($stats.rawAppBar)" -ForegroundColor $(if ($stats.rawAppBar -gt 0) {"Yellow"} else {"Green"})

if ($errors.Count -gt 0) { Write-Host "`nERRORS ($($errors.Count))" -ForegroundColor Red; $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red } }
if ($warnings.Count -gt 0) { Write-Host "`nWARNINGS ($($warnings.Count))" -ForegroundColor Yellow; $warnings | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow } }
