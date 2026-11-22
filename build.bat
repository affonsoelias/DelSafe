@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   AetherLang Compiler (aetherc) - Quick Build Script
echo ========================================================

:: Check for FPC in PATH
where fpc >nul 2>nul
if %ERRORLEVEL% equ 0 (
    set FPC_BIN=fpc
    goto :COMPILE
)

:: Common installation paths for Free Pascal / Lazarus on Windows
if exist "C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe" (
    set "PATH=C:\lazarus\fpc\3.2.2\bin\x86_64-win64;!PATH!"
    set FPC_BIN=fpc
    goto :COMPILE
)

if exist "C:\fpc\3.2.2\bin\i386-win32\fpc.exe" (
    set "PATH=C:\fpc\3.2.2\bin\i386-win32;!PATH!"
    set FPC_BIN=fpc
    goto :COMPILE
)

if exist "C:\lazarus\fpc\3.2.0\bin\x86_64-win64\fpc.exe" (
    set "PATH=C:\lazarus\fpc\3.2.0\bin\x86_64-win64;!PATH!"
    set FPC_BIN=fpc
    goto :COMPILE
)

echo [ERROR] Free Pascal Compiler (fpc) was not found in your PATH or common directories.
echo Please install Free Pascal (https://www.freepascal.org/) or Lazarus and ensure 'fpc' is accessible.
exit /b 1

:COMPILE
echo [*] Free Pascal found. Creating build directories...
if not exist "bin" mkdir bin
if not exist "build" mkdir build

echo [*] Compiling aetherc compiler...
fpc -MObjFPC -Sc -O2 -FEbin -FUbuild -Fucompiler/src compiler/aetherc.lpr

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Compilation failed!
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] aetherc compiled successfully to: bin\aetherc.exe
echo.
echo [*] Running quick diagnostic test:
bin\aetherc.exe --version
bin\aetherc.exe test

echo.
echo ========================================================
echo   Build complete! You can run 'bin\aetherc' now.
echo ========================================================
exit /b 0
