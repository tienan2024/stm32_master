@echo off
REM STM32 Serial Monitor Extension - Quick Build & Install Script

setlocal enabledelayedexpansion

echo.
echo ========================================
echo   STM32 Serial Monitor - Build Setup
echo ========================================
echo.

REM Check Node.js
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Node.js not found. Please install Node.js first.
    echo    Download: https://nodejs.org/
    pause
    exit /b 1
)

echo ✅ Node.js found
node --version

REM Check npm
where npm >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ npm not found.
    pause
    exit /b 1
)

echo ✅ npm found
npm --version
echo.

REM Install dependencies
echo [1/4] Installing dependencies...
call npm install
if %ERRORLEVEL% NEQ 0 (
    echo ❌ npm install failed
    pause
    exit /b 1
)

echo ✅ Dependencies installed
echo.

REM Compile TypeScript
echo [2/4] Compiling TypeScript...
call npm run compile
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Compilation failed
    pause
    exit /b 1
)

echo ✅ TypeScript compiled
echo.

REM Check VS Code
echo [3/4] Checking VS Code...
where code >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️  VS Code command not found. Please ensure VS Code is installed and added to PATH.
    echo    You can manually install the VSIX file later.
) else (
    echo ✅ VS Code found
    
    REM Build VSIX
    echo.
    echo [4/4] Building VSIX package...
    
    REM Check vsce
    where vsce >nul 2>nul
    if %ERRORLEVEL% NEQ 0 (
        echo ⚠️  vsce not found. Installing globally...
        call npm install -g @vscode/vsce
    )
    
    call vsce package
    if %ERRORLEVEL% NEQ 0 (
        echo ❌ VSIX build failed
        pause
        exit /b 1
    )
    
    echo ✅ VSIX package created
    echo.
    
    REM Install extension
    echo [5/5] Installing extension to VS Code...
    for /f "tokens=*" %%i in ('dir /b *.vsix') do (
        call code --install-extension "%%i" --force
        if !ERRORLEVEL! EQU 0 (
            echo ✅ Extension installed successfully
            echo.
            echo 🎉 Done! Restart VS Code to activate the extension.
        ) else (
            echo ⚠️  Failed to install extension automatically.
            echo    Please manually install: %%i
        )
    )
)

echo.
echo ========================================
echo   Setup Complete!
echo ========================================
echo.
echo Next steps:
echo   1. Open/Restart VS Code
echo   2. Go to Extensions and enable "STM32 Serial Monitor"
echo   3. Click the "Serial Monitor" icon in the Activity Bar (left sidebar)
echo   4. Click "Select" to choose your COM port
echo   5. Click "Start" to begin monitoring
echo.

pause
