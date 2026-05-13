@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

echo ============================================
echo   闲鱼自动回复 - 停止所有服务
echo ============================================
echo.

REM === 停止应用服务 ===
for %%P in (8089 8090 8091) do (
    set "FOUND=0"
    for /f "tokens=5" %%A in ('netstat -ano ^| findstr /R /C:":%%P .*LISTENING" 2^>nul') do (
        set "FOUND=1"
        echo [停止] 端口 %%P 的进程 PID=%%A
        taskkill /F /PID %%A >nul 2>&1
    )
    if "!FOUND!"=="0" echo [跳过] 端口 %%P 无运行进程
)

REM === 停止 Redis ===
set REDIS_FOUND=0
for /f "tokens=5" %%A in ('netstat -ano ^| findstr /R /C:":6379 .*LISTENING" 2^>nul') do (
    set REDIS_FOUND=1
    echo [停止] Redis 进程 PID=%%A
    taskkill /F /PID %%A >nul 2>&1
)
if "!REDIS_FOUND!"=="0" echo [跳过] Redis 未运行

REM === 停止 MySQL ===
set MYSQL_FOUND=0
for /f "tokens=5" %%A in ('netstat -ano ^| findstr /R /C:":3306 .*LISTENING" 2^>nul') do (
    set MYSQL_FOUND=1
    echo [停止] MySQL 进程 PID=%%A
    taskkill /F /PID %%A >nul 2>&1
)
if "!MYSQL_FOUND!"=="0" echo [跳过] MySQL 未运行

echo.
echo 所有服务已停止。
pause
