@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0..\client_flutter"

REM proxy for flutter pub get / sqlite3 native hook downloading from GitHub Release
set HTTP_PROXY=http://127.0.0.1:20121
set HTTPS_PROXY=http://127.0.0.1:20121

@REM call flutter clean
taskkill /f /im java.exe >nul 2>&1
timeout /t 2 /nobreak >nul
set DART_VM_OPTIONS=--disable-insecure-certificates

set OUTPUT_DIR=%~dp0build
set APP_NAME=notee-android-arm64-v8a

echo Building Android APK...
echo Command: flutter build apk --release
for /f %%i in ('git rev-parse --short HEAD') do set GIT_COMMIT=%%i
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH:mm"') do set BUILD_TIME=%%i
call flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/debug-info/ --dart-define=GIT_COMMIT=%GIT_COMMIT% --dart-define=BUILD_TIME=%BUILD_TIME%
set BUILD_ERROR=!errorlevel!
echo Build exit code: !BUILD_ERROR!

if !BUILD_ERROR! neq 0 (
    echo Failed to build APK with error code: !BUILD_ERROR!
    exit /b 1
)

echo APK built successfully!
echo.
echo Copying APK to output directory...
if not exist "%OUTPUT_DIR%\" mkdir "%OUTPUT_DIR%\"
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy "build\app\outputs\flutter-apk\app-release.apk" "%OUTPUT_DIR%\%APP_NAME%.apk" /Y
) else (
    echo Warning: APK file not found for copying
    exit /b 1
)

echo.
echo success: %OUTPUT_DIR%\%APP_NAME%.apk
exit /b 0
