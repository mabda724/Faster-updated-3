@echo off
cd /d "D:\My_Projects\Faster"

echo Running flutter analyze...
flutter analyze --no-pub > analysis.txt 2>&1
if errorlevel 1 (
    echo Errors found! Check analysis.txt
    pause
    exit /b 1
)
echo Analyze passed.

echo Running flutter test...
flutter test > test_results.txt 2>&1
if errorlevel 1 (
    echo Tests failed! Check test_results.txt
    pause
    exit /b 1
)
echo Tests passed.

echo Building release APK...
flutter build apk --release
if errorlevel 1 (
    echo Build failed!
    pause
    exit /b 1
)
echo Build successful: build/app/outputs/flutter-apk/app-release.apk
pause
