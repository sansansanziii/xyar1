@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

REM --- 设置 Playwright 浏览器路径 ---
set "PLAYWRIGHT_BROWSERS_PATH=%~dp0ms-playwright"

echo ============================================
echo   闲鱼自动回复 - 一键启动
echo ============================================
echo.

set "MYSQL_DIR=%~dp0infrastructure\mysql"
set "REDIS_DIR=%~dp0infrastructure\redis"
set "MYSQL_DATA=%MYSQL_DIR%\data"
set "MY_CNF=%MYSQL_DIR%\my.ini"
set "REDIS_CONF=%REDIS_DIR%\redis.windows.conf"

REM === 检查 MySQL 目录 ===
if not exist "%MYSQL_DIR%\bin\mysqld.exe" (
    echo [错误] 未找到 MySQL: %MYSQL_DIR%\bin\mysqld.exe
    goto :end
)

REM === 检查 Redis 目录 ===
if not exist "%REDIS_DIR%\redis-server.exe" (
    echo [错误] 未找到 Redis: %REDIS_DIR%\redis-server.exe
    goto :end
)

REM =============================================
REM 1. 首次运行：初始化 MySQL 数据目录
REM =============================================
if not exist "%MYSQL_DATA%\mysql" (
    echo [1/6] 首次运行，正在初始化 MySQL 数据目录...
    cd /d "%MYSQL_DIR%"
    bin\mysqld.exe --defaults-file="%MY_CNF%" --initialize-insecure --console 2>&1
    if errorlevel 1 (
        echo [错误] MySQL 初始化失败。
        cd /d "%~dp0"
        goto :end
    )
    cd /d "%~dp0"
    echo [1/6] MySQL 初始化完成。
) else (
    echo [1/6] MySQL 数据目录已存在，跳过初始化。
)

REM =============================================
REM 2. 启动 MySQL
REM =============================================
echo [2/6] 启动 MySQL...
cd /d "%MYSQL_DIR%"
start "MySQL" /B bin\mysqld.exe --defaults-file="%MY_CNF%" --console
cd /d "%~dp0"

set MYSQL_READY=0
for /L %%i in (1,1,30) do (
    if "!MYSQL_READY!"=="0" (
        netstat -ano | findstr /R /C:":3306 .*LISTENING" >nul 2>&1
        if not errorlevel 1 (
            set MYSQL_READY=1
        ) else (
            timeout /t 1 /nobreak >nul
        )
    )
)
if "!MYSQL_READY!"=="0" (
    echo [错误] MySQL 启动超时（30秒）
    goto :end
)
echo [2/6] MySQL 已启动。

REM =============================================
REM 3. 启动 Redis
REM =============================================
echo [3/6] 启动 Redis...
cd /d "%REDIS_DIR%"
start "Redis" /B redis-server.exe redis.windows.conf
cd /d "%~dp0"

set REDIS_READY=0
for /L %%i in (1,1,15) do (
    if "!REDIS_READY!"=="0" (
        netstat -ano | findstr /R /C:":6379 .*LISTENING" >nul 2>&1
        if not errorlevel 1 (
            set REDIS_READY=1
        ) else (
            timeout /t 1 /nobreak >nul
        )
    )
)
if "!REDIS_READY!"=="0" (
    echo [错误] Redis 启动超时（15秒）
    goto :stop_mysql
)
echo [3/6] Redis 已启动。

REM =============================================
REM 4. 初始化数据库 + 配置
REM =============================================
echo [4/6] 初始化数据库和配置...

REM --- 授权 root 用户通过 TCP 连接 ---
"%MYSQL_DIR%\bin\mysql.exe" -u root --skip-password --pipe --socket=mysql -e "CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY ''; GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>nul

python scripts\setup_embedded.py
if errorlevel 1 (
    echo [警告] 环境初始化出现问题，继续启动服务...
)

REM =============================================
REM 5. 启动后端服务
REM =============================================
echo [5/6] 启动后端服务...

start "Backend-Web" /B python backend-web\main.py
timeout /t 3 /nobreak >nul
start "WebSocket" /B python websocket\main.py
timeout /t 2 /nobreak >nul
start "Scheduler" /B python scheduler\main.py
timeout /t 2 /nobreak >nul

echo [5/6] 后端服务已启动。
echo       Backend-Web : http://localhost:8089
echo       WebSocket   : http://localhost:8090
echo       Scheduler   : http://localhost:8091

REM =============================================
REM 6. 启动前端
REM =============================================
echo [6/6] 启动前端...
start "Frontend" /B python scripts\frontend_server.py
timeout /t 2 /nobreak >nul

echo.
echo ============================================
echo   所有服务已启动！
echo   前端地址：http://localhost:9000
echo   按 Ctrl+C 停止所有服务
echo ============================================
echo.

REM --- 自动打开浏览器 ---
start http://localhost:9000

REM --- 等待用户中断 ---
pause

REM =============================================
REM 退出清理
REM =============================================
echo.
echo 正在停止所有服务...

call stop.bat

goto :end

:end
echo.
