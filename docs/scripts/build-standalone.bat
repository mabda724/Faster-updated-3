@echo off
REM =====================================================================
REM Faster Demo Build Script
REM =====================================================================
REM This script builds the DEMO version of Faster with:
REM   - Mock service layer (no real backend connections)
REM   - Code obfuscation via --obfuscate
REM   - Split debug info for minimal reverse-engineering surface
REM   - Watermarked demo splash screen
REM   - All real API keys/servers disconnected
REM =====================================================================

setlocal enabledelayedexpansion

echo.
echo ============================================
echo  Faster Demo Build
echo  Training ^& Demonstration Purpose Only
echo ============================================
echo.

REM ---- Check for Flutter ----
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter not found in PATH
    echo Please install Flutter SDK ^>=3.8.0
    exit /b 1
)

echo [STEP 1/4] Cleaning previous builds...
call flutter clean
if %ERRORLEVEL% NEQ 0 (
    echo [WARN] Clean failed, continuing...
)

echo [STEP 2/4] Installing dependencies...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to install dependencies
    exit /b 1
)

echo [STEP 3/4] Building Demo APK (debug mode, obfuscated)...
call flutter build apk --debug ^
    --obfuscate ^
    --split-debug-info=build/debug-info ^
    --dart-define=FLUTTER_APP_FLAVOR=demo ^
    --target=lib/main_demo.dart

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Build failed. Check errors above.
    echo Try: flutter build apk --debug
    exit /b 1
)

echo [STEP 4/4] Demo build complete!
echo.
echo Output: build\app\outputs\flutter-apk\app-debug.apk
echo.
echo ============================================
echo  Demo Build Successful
echo  This build contains NO real business logic.
echo  NOT for production use.
echo ============================================

endlocal
pause
