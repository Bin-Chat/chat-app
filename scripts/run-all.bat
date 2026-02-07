@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   CHAT APP - ONE COMMAND STARTUP
echo ========================================
echo.

REM Check Docker
echo [1/6] Checking Docker...
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
echo [2/6] Checking Node.js...
node -v >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed!
    pause
    exit /b 1
)
echo [OK] Node.js is ready

REM Install dependencies if needed
echo.
echo [3/6] Checking dependencies...
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
echo [4/6] Starting infrastructure...
docker-compose up -d postgres
echo Waiting 15 seconds for database...
timeout /t 15 /nobreak >nul
echo [OK] Infrastructure started

REM Start backend services
echo.
echo [5/6] Starting backend services...
echo This may take 5-10 minutes on first run...
docker-compose up -d --build api-gateway auth-service

REM Start frontend
echo.
echo [6/6] Starting frontend...
start "Chat App - Frontend" cmd /k "cd /d "%~dp0..\apps\web" && npm run dev"

echo.
echo ========================================
echo   ALL SERVICES STARTING!
echo ========================================
echo.
echo A new window opened for the frontend.
echo.
echo Service URLs:
echo   Frontend:              http://localhost:5173
echo   API Gateway:           http://localhost:3000
echo   Auth Service:          http://localhost:3010
echo   Database (Postgres):   localhost:5432
echo.
echo Backend services are building in background...
echo Check status: docker-compose ps
echo View logs: docker-compose logs -f
echo.
echo Press Ctrl+C in frontend window to stop it
echo Run stop-all.bat to stop everything
echo.
pause
