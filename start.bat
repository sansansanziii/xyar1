@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

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
    echo 请确认 infrastructure\mysql\bin\ 目录存在。
    goto :end
)

REM === 检查 Redis 目录 ===
if not exist "%REDIS_DIR%\redis-server.exe" (
    echo [错误] 未找到 Redis: %REDIS_DIR%\redis-server.exe
    echo 请确认 infrastructure\redis\ 目录存在。
    goto :end
)

REM =============================================
REM 1. 首次运行：初始化 MySQL 数据目录
REM =============================================
if not exist "%MYSQL_DATA%\mysql" (
    echo [1/4] 首次运行，正在初始化 MySQL 数据目录...
    cd /d "%MYSQL_DIR%"
    bin\mysqld.exe --defaults-file="%MY_CNF%" --initialize-insecure --console 2>&1
    if errorlevel 1 (
        echo [错误] MySQL 初始化失败。
        cd /d "%~dp0"
        goto :end
    )
    cd /d "%~dp0"
    echo [1/4] MySQL 初始化完成。
) else (
    echo [1/4] MySQL 数据目录已存在，跳过初始化。
)

REM =============================================
REM 2. 启动 MySQL
REM =============================================
echo [2/4] 启动 MySQL...
cd /d "%MYSQL_DIR%"
start "MySQL" /B bin\mysqld.exe --defaults-file="%MY_CNF%" --console
cd /d "%~dp0"

REM 等待 MySQL 端口就绪
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
echo [2/4] MySQL 已启动。

REM =============================================
REM 3. 启动 Redis
REM =============================================
echo [3/4] 启动 Redis...
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
echo [3/4] Redis 已启动。

REM =============================================
REM 4. 初始化数据库 + 配置 + 启动主程序
REM =============================================
echo [4/4] 初始化环境并启动主程序...

REM --- 授权 root 用户通过 TCP 连接（initialize-insecure 只允许 named pipe）---
"%MYSQL_DIR%\bin\mysql.exe" -u root --skip-password --pipe --socket=mysql -e "CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY ''; GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION; FLUSH PRIVILEGES;"
if errorlevel 1 (
    echo [警告] MySQL 用户授权失败，尝试跳过...
)

python scripts\setup_embedded.py
if errorlevel 1 (
    echo [警告] 环境初始化出现问题，继续启动主程序...
)

if exist "XianyuAutoReply.exe" (
    echo.
    echo ============================================
    echo   正在启动 XianyuAutoReply...
    echo   关闭主程序窗口后将自动停止 MySQL/Redis
    echo ============================================
    echo.
    start "" /wait XianyuAutoReply.exe
) else if exist "python.exe" (
    echo.
    echo [提示] 未找到 XianyuAutoReply.exe，使用开发模式启动...
    python launcher\main.py
) else (
    echo [错误] 未找到 XianyuAutoReply.exe
)

REM =============================================
REM 退出清理
REM =============================================
echo.
echo 正在停止服务...

:stop_redis
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":6379 .*LISTENING"') do (
    taskkill /F /PID %%P >nul 2>&1
)
echo Redis 已停止。

:stop_mysql
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":3306 .*LISTENING"') do (
    taskkill /F /PID %%P >nul 2>&1
)
echo MySQL 已停止。

echo.
echo 所有服务已停止。
goto :end

:end
echo.
pause
