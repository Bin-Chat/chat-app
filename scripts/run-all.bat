@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   CHAT APP - ONE COMMAND STARTUP
echo ========================================
echo.

REM Check Docker
echo [1/7] Checking Docker...
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running!
    echo Starting Docker Desktop...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    echo Waiting for Docker to start...
    timeout /t 30 /nobreak >nul
)
echo [OK] Docker is ready

REM Check Node
echo.
echo [2/7] Checking Node.js...
node -v >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed!
    pause
    exit /b 1
)
echo [OK] Node.js is ready

REM Install dependencies if needed
echo.
echo [3/7] Checking dependencies...
cd ..
if not exist "node_modules" (
    echo Installing root dependencies...
    call npm install
)
if not exist "apps\web\node_modules" (
    echo Installing web app dependencies...
    cd apps\web
    call npm install
    cd ..\..
)
echo [OK] Dependencies ready

REM Start infrastructure
echo.
echo [4/7] Starting infrastructure...
docker-compose up -d postgres redis redpanda
echo Waiting 15 seconds for infrastructure...
timeout /t 15 /nobreak >nul
echo [OK] Infrastructure started

REM Start backend services
echo.
echo [5/7] Starting backend services...
echo This may take 5-10 minutes on first run...
docker-compose up -d --build api-gateway auth-service user-service notification-service friend-service upload-service

REM Start frontend
echo.
echo [6/7] Starting frontend...
start "Chat App - Frontend" cmd /k "cd /d "%~dp0..\apps\web" && npm run dev"

REM Start mobile app (Expo)
echo.
echo [7/7] Starting mobile app (Expo)...
if not exist "%~dp0..\apps\mobile\node_modules" (
    echo Installing mobile app dependencies...
    cd "%~dp0..\apps\mobile"
    call npm install
    cd "%~dp0"
)
start "Chat App - Mobile (Expo)" cmd /k "cd /d "%~dp0..\apps\mobile" && set NODE_PATH=%~dp0..\apps\mobile\node_modules && npx expo start --offline"

echo.
echo ========================================
echo   ALL SERVICES STARTING!
echo ========================================
echo.
echo New windows opened for frontend and mobile app.
echo.
echo Service URLs:
echo   Frontend:              http://localhost:5173
echo   API Gateway:           http://localhost:3000
echo   Auth Service:          http://localhost:3010
echo   User Service:          http://localhost:3020
echo   Friend Service:        http://localhost:3025
echo   Notification Service:  http://localhost:3030
echo   Upload Service:        http://localhost:3035
echo   Mobile (Expo):         Scan QR code in opened window
echo   Database (Postgres):   localhost:5432
echo   Redis:                 localhost:6379
echo   Redpanda (Kafka):      localhost:19092
echo.
echo Backend services are building in background...
echo Check status: docker-compose ps
echo View logs: docker-compose logs -f
echo.
echo Press Ctrl+C in frontend/mobile windows to stop them
echo Run stop-all.bat to stop everything
echo.
pause

