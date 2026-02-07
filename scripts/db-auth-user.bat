@echo off
REM ========================================
REM DATABASE CONNECTION SCRIPT
REM ========================================

echo ========================================
echo   PostgreSQL Database Connection
echo ========================================
echo.
echo Database: chatapp
echo User: chatapp
echo Host: localhost:5432
echo.
echo Connecting...
echo.

REM Set password environment variable
set PGPASSWORD=ngocanh123

REM Kết nối vào PostgreSQL
docker exec -e PGPASSWORD=%PGPASSWORD% -it chat-postgres psql -U chatapp -d chatapp

echo.
echo Connection closed.
pause
