@echo off

REM Navigate to project root (parent of scripts folder)
cd /d "%~dp0.."

echo ====================================
echo Git Submodules Setup Script
echo ====================================
echo.

echo [1/3] Initializing and updating submodules...
git submodule update --init --recursive
if %errorlevel% neq 0 (
    echo Error: Failed to initialize submodules
    exit /b 1
)
echo.

echo [2/3] Installing dependencies for each submodule...
echo.

echo --- Installing dependencies for apps/web ---
if exist "apps\web\package.json" (
    cd apps\web
    call npm install
    if errorlevel 1 (
        echo Error: Failed to install dependencies for apps/web
        exit /b 1
    )
    cd ..\..
) else (
    echo Skipping apps/web - package.json not found
)
echo.

echo --- Installing dependencies for apps/mobile ---
if exist "apps\mobile\package.json" (
    cd apps\mobile
    call npm install
    if errorlevel 1 (
        echo Error: Failed to install dependencies for apps/mobile
        exit /b 1
    )
    cd ..\..
) else (
    echo Skipping apps/mobile - package.json not found
)
echo.

echo --- Installing dependencies for services/auth ---
if exist "services\auth\package.json" (
    cd services\auth
    call npm install
    if errorlevel 1 (
        echo Error: Failed to install dependencies for services/auth
        exit /b 1
    )
    cd ..\..
) else (
    echo Skipping services/auth - package.json not found
)
echo.

echo --- Installing dependencies for services/user ---
if exist "services\user\package.json" (
    cd services\user
    call npm install
    if errorlevel 1 (
        echo Error: Failed to install dependencies for services/user
        exit /b 1
    )
    cd ..\..
) else (
    echo Skipping services/user - package.json not found
)
echo.

echo --- Installing dependencies for services/notification ---
if exist "services\notification\package.json" (
    cd services\notification
    call npm install
    if errorlevel 1 (
        echo Error: Failed to install dependencies for services/notification
        exit /b 1
    )
    cd ..\..
) else (
    echo Skipping services/notification - package.json not found
)
echo.

echo --- Installing dependencies for services/chat ---
if exist "services\chat\package.json" (
    cd services\chat
    call npm install
    if errorlevel 1 (
        echo Error: Failed to install dependencies for services/chat
        exit /b 1
    )
    cd ..\..
) else (
    echo Skipping services/chat - package.json not found
)
echo.

echo --- Installing dependencies for services/friend ---
if exist "services\friend\package.json" (
    cd services\friend
    call npm install
    if errorlevel 1 (
        echo Error: Failed to install dependencies for services/friend
        exit /b 1
    )
    cd ..\..
) else (
    echo Skipping services/friend - package.json not found
)
echo.

echo --- Installing dependencies for services/upload ---
if exist "services\upload\package.json" (
    cd services\upload
    call npm install
    if errorlevel 1 (
        echo Error: Failed to install dependencies for services/upload
        exit /b 1
    )
    cd ..\..
) else (
    echo Skipping services/upload - package.json not found
)
echo.

echo --- Installing dependencies for services/ai ---
if exist "services\ai\package.json" (
    cd services\ai
    call npm install --legacy-peer-deps
    if errorlevel 1 (
        echo Error: Failed to install dependencies for services/ai
        exit /b 1
    )
    cd ..\..
) else (
    echo Skipping services/ai - package.json not found
)
echo.

echo --- Installing dependencies for gateway ---
if exist "gateway\api-gateway\package.json" (
    cd gateway\api-gateway
    call npm install
    if errorlevel 1 (
        echo Error: Failed to install dependencies for gateway/api-gateway
        exit /b 1
    )
    cd ..\..
) else if exist "gateway\package.json" (
    cd gateway
    call npm install
    if errorlevel 1 (
        echo Error: Failed to install dependencies for gateway
        exit /b 1
    )
    cd ..
) else (
    echo Skipping gateway - package.json not found
)
echo.

echo [3/3] Setup complete!
echo.
echo ====================================
echo All submodules are ready!
echo ====================================
pause
