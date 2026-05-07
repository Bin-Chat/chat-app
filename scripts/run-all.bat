@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   CHAT APP - ONE COMMAND STARTUP
echo ========================================
echo.

REM Resolve root directory (scripts\ is one level deep)
pushd "%~dp0.."
set "ROOT_DIR=%CD%"
popd

REM Check Docker
echo [1/7] Checking Docker...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker is not running!
    echo Starting Docker Desktop...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    echo Waiting 30 seconds for Docker to start...
    timeout /t 30 /nobreak >nul
)
echo [OK] Docker is ready

REM Check Node
echo.
echo [2/7] Checking Node.js...
node -v >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed!
    pause
    exit /b 1
)
echo [OK] Node.js is ready

REM Install dependencies if needed
echo.
echo [3/7] Checking dependencies...
if not exist "%ROOT_DIR%\node_modules" (
    echo Installing root dependencies...
    pushd "%ROOT_DIR%"
    call npm install
    popd
)
if not exist "%ROOT_DIR%\apps\web\node_modules" (
    echo Installing web app dependencies...
    pushd "%ROOT_DIR%\apps\web"
    call npm install
    popd
)
if not exist "%ROOT_DIR%\apps\mobile\node_modules" (
    echo Installing mobile app dependencies...
    pushd "%ROOT_DIR%\apps\mobile"
    call npm install
    popd
)
if not exist "%ROOT_DIR%\services\ai\node_modules" (
    echo Installing AI service dependencies...
    pushd "%ROOT_DIR%\services\ai"
    call npm install --legacy-peer-deps
    popd
)
echo [OK] Dependencies ready

REM Start infrastructure (Postgres, Redis, MongoDB, Redpanda/Kafka)
echo.
echo [4/7] Starting infrastructure...
pushd "%ROOT_DIR%"
docker-compose up -d postgres redis mongo redpanda qdrant
popd
echo Waiting 20 seconds for infrastructure to be healthy...
timeout /t 20 /nobreak >nul
echo [OK] Infrastructure started

REM Start backend microservices
echo.
echo [5/7] Starting backend services...
echo This may take 5-10 minutes on first run (Docker build)...
pushd "%ROOT_DIR%"
docker-compose up -d --build ^
    auth-service ^
    user-service ^
    notification-service ^
    friend-service ^
    upload-service ^
    chat-service ^
    ai-service ^
    api-gateway
popd
echo [OK] Backend services building in background

REM Start web frontend (use /D to avoid nested quotes with paths)
echo.
echo [6/7] Starting web frontend...
start "Chat App - Frontend" /D "%ROOT_DIR%\apps\web" cmd /k npm run dev

REM Start mobile app (Expo)
echo.
echo [7/7] Starting mobile app (Expo)...
start "Chat App - Mobile (Expo)" /D "%ROOT_DIR%\apps\mobile" cmd /k npx expo start

echo.
echo ========================================
echo   ALL SERVICES STARTING!
echo ========================================
echo.
echo New windows opened for frontend and mobile app.
echo.
echo Service URLs:
echo   Frontend (Web):        http://localhost:5173
echo   API Gateway:           http://localhost:3000
echo   Auth Service:          http://localhost:3010
echo   User Service:          http://localhost:3020
echo   Friend Service:        http://localhost:3025
echo   Notification Service:  http://localhost:3030
echo   Upload Service:        http://localhost:3035
echo   Chat Service:          http://localhost:3040
echo   AI Service:            http://localhost:3050
echo   Mobile (Expo):         Scan QR code in Expo window
echo.
echo Infrastructure:
echo   PostgreSQL:            localhost:5432
echo   Redis:                 localhost:6379
echo   MongoDB:               localhost:27017
echo   Redpanda (Kafka):      localhost:19092
echo   Qdrant (Vector DB):    localhost:6333
echo.
echo Useful commands:
echo   Check status:  docker-compose ps
echo   View logs:     docker-compose logs -f [service-name]
echo   Stop all:      scripts\stop-all.bat
echo.
pause

