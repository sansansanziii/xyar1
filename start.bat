@echo off
setlocal EnableDelayedExpansion
chcp 65001 >/dev/null
cd /d "%~dp0"

REM --- Playwright ---
set "PLAYWRIGHT_BROWSERS_PATH=%~dp0ms-playwright"

REM --- Python path ---
set "PYTHONPATH=%~dp0site-packages;%~dp0"

REM --- Embedded Python ---
set "PY=%~dp0python.exe"
if not exist "%PY%" (
    echo [error] python.exe not found in current directory.
    goto :end
)

echo ============================================
echo   xianyu-auto-reply - start
echo ============================================
echo.

set "MYSQL_DIR=%~dp0infrastructure\mysql"
set "REDIS_DIR=%~dp0infrastructure\redis"
set "MYSQL_DATA=%MYSQL_DIR%data"
set "MY_CNF=%MYSQL_DIR%my.ini"

if not exist "%MYSQL_DIR%bin\mysqld.exe" (
    echo [error] MySQL not found: %MYSQL_DIR%bin\mysqld.exe
    goto :end
)

if not exist "%REDIS_DIR%redis-server.exe" (
    echo [error] Redis not found: %REDIS_DIR%redis-server.exe
    goto :end
)

REM === 1. Init MySQL ===
if not exist "%MYSQL_DATA%mysql" (
    echo [1/6] Initializing MySQL...
    cd /d "%MYSQL_DIR%"
    bin\mysqld.exe --defaults-file="%MY_CNF%" --initialize-insecure --console 2>&1
    if errorlevel 1 (
        echo [error] MySQL init failed.
        cd /d "%~dp0"
        goto :end
    )
    cd /d "%~dp0"
    echo [1/6] MySQL initialized.
) else (
    echo [1/6] MySQL data exists, skipping init.
)

REM === 2. Start MySQL ===
echo [2/6] Starting MySQL...
cd /d "%MYSQL_DIR%"
start "MySQL" /B bin\mysqld.exe --defaults-file="%MY_CNF%" --console
cd /d "%~dp0"
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
    echo [error] MySQL startup timeout.
    goto :end
)
echo [2/6] MySQL started.

REM === 3. Start Redis ===
echo [3/6] Starting Redis...
cd /d "%REDIS_DIR%"
start "Redis" /B redis-server.exe redis.windows.conf
cd /d "%~dp0"
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
    echo [error] Redis startup timeout.
    goto :stop_mysql
)
echo [3/6] Redis started.

REM === 4. Init database ===
echo [4/6] Initializing database...
"%MYSQL_DIR%bin\mysql.exe" -u root --skip-password --pipe --socket=mysql -e "CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY ''; GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>/dev/null
"%PY%" scripts\setup_embedded.py
if errorlevel 1 (
    echo [warn] Setup had issues, continuing...
)

REM === 5. Start backend services ===
echo [5/6] Starting backend services...
start "Backend-Web" /B "%PY%" backend-web\main.py
timeout /t 3 /nobreak >/dev/null
start "WebSocket" /B "%PY%" websocket\main.py
timeout /t 2 /nobreak >/dev/null
start "Scheduler" /B "%PY%" scheduler\main.py
timeout /t 2 /nobreak >/dev/null
echo [5/6] Backend services started.
echo       Backend-Web : http://localhost:8089
echo       WebSocket   : http://localhost:8090
echo       Scheduler   : http://localhost:8091

REM === 6. Start frontend ===
echo [6/6] Starting frontend...
start "Frontend" /B "%PY%" scripts\frontend_server.py
timeout /t 2 /nobreak >/dev/null

echo.
echo ============================================
echo   All services started!
echo   Frontend: http://localhost:9000
echo ============================================
echo.

start http://localhost:9000
pause

echo.
echo Stopping all services...
call stop.bat
goto :end

:stop_redis
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":6379 .*LISTENING"') do (
    taskkill /F /PID %%P >/dev/null 2>&1
)
echo Redis stopped.

:stop_mysql
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":3306 .*LISTENING"') do (
    taskkill /F /PID %%P >/dev/null 2>&1
)
echo MySQL stopped.

echo All services stopped.
goto :end

:end
echo.
