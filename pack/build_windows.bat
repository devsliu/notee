@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0..\client_flutter"

rem === 设置代理, 供 flutter pub get / sqlite3 native hook 下载 GitHub Release ===
rem 需要本机代理端口为 20121 (Clash / v2rayN 之类)
set HTTP_PROXY=http://127.0.0.1:20121
set HTTPS_PROXY=http://127.0.0.1:20121

echo === Proxy set: %HTTP_PROXY% ===
echo.

echo === Killing any running app processes that may lock DLLs ===
taskkill /F /IM notee.exe 2>nul
timeout /t 1 /nobreak >nul

echo === Flutter clean ===
call flutter clean

echo === Force-removing native asset caches (avoids MSB8066 lock issues) ===
if exist ".dart_tool\hooks_runner" (
    rmdir /s /q ".dart_tool\hooks_runner" 2>nul
    echo   Removed .dart_tool\hooks_runner
)
if exist "build\windows\x64\CMakeFiles" (
    rmdir /s /q "build\windows\x64\CMakeFiles" 2>nul
    echo   Removed CMakeFiles
)
if exist "build\windows\x64\flutter" (
    rmdir /s /q "build\windows\x64\flutter" 2>nul
    echo   Removed build/windows/x64/flutter
)

echo === Flutter pub get ===
call flutter pub get

rem 输出到项目根 build/ (文件名自带平台标识)
set OUTPUT_DIR=%~dp0build
set APP_NAME=notee-client-windows-x64

echo Building Windows release...
echo Command: flutter build windows --release
for /f %%i in ('git rev-parse --short HEAD') do set GIT_COMMIT=%%i
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH:mm"') do set BUILD_TIME=%%i
call flutter build windows --release --obfuscate --split-debug-info=build/debug-info/ --dart-define=GIT_COMMIT=%GIT_COMMIT% --dart-define=BUILD_TIME=%BUILD_TIME%
set WINDOWS_ERROR=!errorlevel!
echo Windows build exit code: !WINDOWS_ERROR!

if !WINDOWS_ERROR! neq 0 (
    echo Failed to build Windows application with error code: !WINDOWS_ERROR!
    echo.
    exit /b 1
) else (
    echo Windows application built successfully!
    echo.
)

echo.
echo Creating ZIP package...

rem 检查构建输出目录
if not exist "build\windows\x64\runner\Release" (
    echo Error: Windows build output directory not found!
    echo Expected: build\windows\x64\runner\Release
    exit /b 1
)

rem 创建临时目录用于打包
set TEMP_DIR=temp_windows_package
if exist "%TEMP_DIR%" (
    echo Removing existing temporary directory...
    rmdir /s /q "%TEMP_DIR%"
)
mkdir "%TEMP_DIR%"

echo Copying Windows application files...
xcopy "build\windows\x64\runner\Release\*" "%TEMP_DIR%\" /E /I /H /Y
if !errorlevel! neq 0 (
    echo Failed to copy Windows application files!
    exit /b 1
)

REM 删掉 kernel_blob.bin (JIT fallback, Release 用 app.dll, 删了省 ~100MB)
del /s /q "%TEMP_DIR%\kernel_blob.bin" 2>nul

echo Creating ZIP file...
rem 使用PowerShell创建ZIP文件
powershell -Command "Compress-Archive -Path '%TEMP_DIR%\*' -DestinationPath 'windows_temp.zip' -Force"
if !errorlevel! neq 0 (
    echo Failed to create ZIP file!
    exit /b 1
)

echo Copying ZIP to output directory...
if not exist "%OUTPUT_DIR%\" mkdir "%OUTPUT_DIR%\"

copy "windows_temp.zip" "%OUTPUT_DIR%\%APP_NAME%.zip" /Y
if !errorlevel! neq 0 (
    echo Failed to copy ZIP to output directory!
    exit /b 1
)

echo Cleaning up temporary files...
del "windows_temp.zip"
rmdir /s /q "%TEMP_DIR%"

echo.
echo Checking final ZIP file:
if exist "%OUTPUT_DIR%\%APP_NAME%.zip" (
    echo success "%APP_NAME%.zip" found at "%OUTPUT_DIR%\"
    for %%A in ("%OUTPUT_DIR%\%APP_NAME%.zip") do echo   File size: %%~zA bytes
) else (
    echo failed %APP_NAME%.zip not found at target location
)

echo.
echo Windows build completed!