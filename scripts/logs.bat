@echo off
echo ================================
echo   VIEW SERVICE LOGS
echo ================================
echo.
echo Available services:
echo   1. chat-service
echo   2. presence-service
echo   3. realtime-gateway
echo   4. media-processor
echo   5. postgres
echo   6. redis
echo   7. redpanda
echo   8. ALL services
echo.

set /p choice="Select service (1-8): "

if "%choice%"=="1" docker-compose logs -f chat-service
if "%choice%"=="2" docker-compose logs -f presence-service
if "%choice%"=="3" docker-compose logs -f realtime-gateway
if "%choice%"=="4" docker-compose logs -f media-processor
if "%choice%"=="5" docker-compose logs -f postgres
if "%choice%"=="6" docker-compose logs -f redis
if "%choice%"=="7" docker-compose logs -f redpanda
if "%choice%"=="8" docker-compose logs -f
