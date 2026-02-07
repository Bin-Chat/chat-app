@echo off
echo ========================================
echo   STOPPING ALL SERVICES
echo ========================================
echo.

echo [1/2] Stopping backend services...
docker-compose down

echo.
echo [2/2] Frontend should be stopped manually...
echo Close the frontend terminal window if it's still running.

echo.
echo All services stopped!
echo.
echo To remove all data (WARNING: deletes database):
echo   docker-compose down -v
echo.
pause
