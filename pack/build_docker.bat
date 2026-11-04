@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0..\server_go\src"

set DOCKER_HOST=
set KO_DATA_PATH=
set KO_DOCKER_REPO=notee

rem 从 version.txt 读取版本号
set /p VERSION=<version.txt
set KO_DEFAULTTAG=%VERSION%

set TARBALL=notee-server-docker-amd64.tar

rem 输出到项目根 build/ (文件名自带平台标识)
set OUTPUT_DIR=%~dp0build
if not exist "%OUTPUT_DIR%\" mkdir "%OUTPUT_DIR%\"

echo === Building Docker image tarball (ko) ===
ko publish --bare --push=false --tarball=%TARBALL% -t %VERSION% .
if !errorlevel! neq 0 (
    echo FAILED: ko build exited with !errorlevel!
    del "%TARBALL%" 2>nul
    exit /b 1
)

copy "%TARBALL%" "%OUTPUT_DIR%\%TARBALL%" /Y
del "%TARBALL%"

echo.
echo OK: %OUTPUT_DIR%\%TARBALL% (%VERSION%)
