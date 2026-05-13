@echo off
setlocal EnableDelayedExpansion
chcp 65001 >/dev/null
cd /d "%~dp0"

set "PLAYWRIGHT_BROWSERS_PATH=%~dp0ms-playwright"
set "PY=%~dp0python.exe"

if not exist "%PY%" (
    echo [FATAL] python.exe not found. Cannot continue.
    goto :end
)

REM --- Verify Python works ---
"%PY%" --version >/dev/null 2>&1
if errorlevel 1 (
    echo [FATAL] python.exe is broken. Cannot continue.
    goto :end
)

echo ============================================
echo   xianyu-auto-reply - start
echo ============================================
echo.

set "MYSQL_DIR=%~dp0infrastructure\mysql"
set "REDIS_DIR=%~dp0infrastructureedis"
set "MYSQL_DATA=%MYSQL_DIR%\data"
set "MY_CNF=%MYSQL_DIR%\my.ini"

if not exist "%MYSQL_DIR%\bin\mysqld.exe" (
    echo [FATAL] MySQL not found: %MYSQL_DIR%\bin\mysqld.exe
    goto :end
)

if not exist "%REDIS_DIR%\redis-server.exe" (
    echo [FATAL] Redis not found: %REDIS_DIR%\redis-server.exe
    goto :end
)

if not exist "%~dp0frontend\dist\index.html" (
    echo [FATAL] Frontend not found: %~dp0frontend\dist\index.html
    goto :end
)

REM =============================================
REM 1. Init MySQL (first run only)
REM =============================================
if not exist "%MYSQL_DATA%\mysql" (
    echo [1/6] Initializing MySQL (first run)...
    pushd "%MYSQL_DIR%"
    bin\mysqld.exe --defaults-file="%MY_CNF%" --initialize-insecure --console 2>&1
    if errorlevel 1 (
        echo [FATAL] MySQL init failed.
        popd
        goto :end
    )
    popd
    echo [1/6] MySQL initialized.
) else (
    echo [1/6] MySQL data exists.
)

REM =============================================
REM 2. Start MySQL
REM =============================================
echo [2/6] Starting MySQL...
pushd "%MYSQL_DIR%"
start "MySQL" /B bin\mysqld.exe --defaults-file="%MY_CNF%" --console > "%~dp0logs\mysql.log" 2>&1
popd

set MYSQL_READY=0
for /L %%i in (1,1,30) do (
    if "!MYSQL_READY!"=="0" (
        netstat -ano | findstr /R /C:":3306 .*LISTENING" >/dev/null 2>&1
        if not errorlevel 1 (
            set MYSQL_READY=1
        ) else (
            timeout /t 1 /nobreak >/dev/null
        )
    )
)
if "!MYSQL_READY!"=="0" (
    echo [FATAL] MySQL did not start. Check logs\mysql.log
    type "%~dp0logs\mysql.log" 2>/dev/null
    goto :end
)
echo [2/6] MySQL OK on port 3306.

REM =============================================
REM 3. Start Redis
REM =============================================
echo [3/6] Starting Redis...
pushd "%REDIS_DIR%"
start "Redis" /B redis-server.exe redis.windows.conf > "%~dp0logs\redis.log" 2>&1
popd

set REDIS_READY=0
for /L %%i in (1,1,15) do (
    if "!REDIS_READY!"=="0" (
        netstat -ano | findstr /R /C:":6379 .*LISTENING" >/dev/null 2>&1
        if not errorlevel 1 (
            set REDIS_READY=1
        ) else (
            timeout /t 1 /nobreak >/dev/null
        )
    )
)
if "!REDIS_READY!"=="0" (
    echo [FATAL] Redis did not start. Check logs\redis.log
    type "%~dp0logs\redis.log" 2>/dev/null
    goto :stop_mysql
)
echo [3/6] Redis OK on port 6379.

REM =============================================
REM 4. Init database
REM =============================================
echo [4/6] Initializing database...
"%MYSQL_DIR%\bin\mysql.exe" -u root --skip-password --pipe --socket=mysql -e "CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY ''; GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>/dev/null

"%PY%" "%~dp0scripts\setup_embedded.py" 2>&1
if errorlevel 1 (
    echo [WARN] Database setup had issues, continuing...
)

REM =============================================
REM 5. Start backend services
REM =============================================
echo [5/6] Starting backend services...

start "Backend-Web" /B "%PY%" "%~dp0backend-web\main.py" > "%~dp0logs\backend-web.log" 2>&1
timeout /t 3 /nobreak >/dev/null

start "WebSocket" /B "%PY%" "%~dp0websocket\main.py" > "%~dp0logs\websocket.log" 2>&1
timeout /t 2 /nobreak >/dev/null

start "Scheduler" /B "%PY%" "%~dp0scheduler\main.py" > "%~dp0logs\scheduler.log" 2>&1
timeout /t 2 /nobreak >/dev/null

REM --- Health check backend-web ---
set BE_READY=0
for /L %%i in (1,1,20) do (
    if "!BE_READY!"=="0" (
        netstat -ano | findstr /R /C:":8089 .*LISTENING" >/dev/null 2>&1
        if not errorlevel 1 (
            set BE_READY=1
        ) else (
            timeout /t 1 /nobreak >/dev/null
        )
    )
)
if "!BE_READY!"=="0" (
    echo [FATAL] Backend-Web did not start on port 8089. Last 10 lines:
    powershell -Command "Get-Content '%~dp0logs\backend-web.log' -Tail 10"
    goto :stop_all
)
echo       Backend-Web OK on :8089

REM =============================================
REM 6. Start frontend
REM =============================================
echo [6/6] Starting frontend on port 9000...
start "Frontend" /B "%PY%" "%~dp0scripts\frontend_server.py" > "%~dp0logs\frontend.log" 2>&1
timeout /t 3 /nobreak >/dev/null

set FE_READY=0
for /L %%i in (1,1,10) do (
    if "!FE_READY!"=="0" (
        netstat -ano | findstr /R /C:":9000 .*LISTENING" >/dev/null 2>&1
        if not errorlevel 1 (
            set FE_READY=1
        ) else (
            timeout /t 1 /nobreak >/dev/null
        )
    )
)
if "!FE_READY!"=="0" (
    echo [FATAL] Frontend did not start on port 9000. Last 10 lines:
    powershell -Command "Get-Content '%~dp0logs\frontend.log' -Tail 10"
    goto :stop_all
)

echo.
echo ============================================
echo   All services running!
echo   Frontend : http://localhost:9000
echo   Backend  : http://localhost:8089
echo   WebSocket: http://localhost:8090
echo   Scheduler: http://localhost:8091
echo   Logs     : logs\*.log
echo ============================================
echo.

start http://localhost:9000
echo Press any key to stop all services...
pause >/dev/null

:stop_all
echo.
echo Stopping all services...
call "%~dp0stop.bat"
goto :end

:stop_redis
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":6379 .*LISTENING"') do taskkill /F /PID %%P >/dev/null 2>&1
echo Redis stopped.

:stop_mysql
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":3306 .*LISTENING"') do taskkill /F /PID %%P >/dev/null 2>&1
echo MySQL stopped.

echo Done.
goto :end

:end
echo.
