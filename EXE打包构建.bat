@echo off
REM === XianyuAutoReply 一键打包脚本 ===
REM 无需 Nuitka / Visual Studio Build Tools
REM 只需 Python 3.12 + Node.js
chcp 65001 >nul
cd /d "%~dp0"

echo ============================================
echo   XianyuAutoReply - One-Click Build
echo ============================================
echo.

REM --- Check Python ---
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python was not found. Please install Python 3.12.
    goto :end
)

REM --- Check node/npm ---
call npm --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] npm was not found. Please install Node.js first.
    goto :end
)

REM --- Read version ---
for /f %%a in ('python -c "from launcher.version import CURRENT_VERSION; print(CURRENT_VERSION)"') do set APP_VER=%%a
if "%APP_VER%"=="" (
    echo [WARN] Failed to read version. Using default version 0.0.1.
    set APP_VER=0.0.1
)
echo [INFO] Current version: v%APP_VER%
echo.

REM --- Detect promotion module ---
set HAS_PROMOTION=0
if exist "promotion\backend\main.py" (
    if exist "promotion\frontend\package.json" (
        set HAS_PROMOTION=1
        echo [INFO] Promotion module detected.
    )
)

echo [1/6] Cleaning old build output...
if exist "release" rmdir /s /q "release"
mkdir release 2>nul

echo [2/6] Building main frontend...
cd frontend
call npm ci --no-audit --no-fund
if errorlevel 1 (
    echo [ERROR] Main frontend npm ci failed.
    cd ..
    goto :end
)
call npm run build
if errorlevel 1 (
    echo [ERROR] Main frontend npm run build failed.
    cd ..
    goto :end
)
cd ..
if not exist "frontend\dist\index.html" (
    echo [ERROR] Main frontend output was not found.
    goto :end
)
echo [INFO] Main frontend build completed.

if "%HAS_PROMOTION%"=="1" (
    echo [2.1/6] Building promotion frontend...
    cd promotion\frontend
    call npm ci --no-audit --no-fund
    if errorlevel 1 (
        echo [ERROR] Promotion frontend npm ci failed.
        cd ..\..
        goto :end
    )
    call npm run build
    if errorlevel 1 (
        echo [ERROR] Promotion frontend npm run build failed.
        cd ..\..
        goto :end
    )
    cd ..\..
    echo [INFO] Promotion frontend build completed.
)

echo [3/6] Downloading MySQL and Redis...

set "DIST_DIR=release\XianyuAutoReply"
mkdir "%DIST_DIR%" 2>nul

REM --- Download MySQL portable ---
if not exist "infrastructure\mysql\bin\mysqld.exe" (
    echo [INFO] Downloading MySQL 8.0 portable...
    powershell -Command "Invoke-WebRequest -Uri 'https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-8.0.46-winx64.zip' -OutFile 'infrastructure\mysql-portable.zip'"
    powershell -Command "Expand-Archive -Path 'infrastructure\mysql-portable.zip' -DestinationPath 'infrastructure' -Force"
    for /d %%D in ("infrastructure\mysql-*") do (
        xcopy /E /I /Y /Q "%%~fD\*" "infrastructure\mysql\" >nul
        rmdir /s /q "%%~fD"
    )
    del /f "infrastructure\mysql-portable.zip" 2>nul
    echo [INFO] MySQL download completed.
) else (
    echo [INFO] MySQL portable already exists.
)

REM --- Download Redis ---
if not exist "infrastructure\redis\redis-server.exe" (
    echo [INFO] Downloading Redis for Windows...
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/tporadowski/redis/releases/download/v5.0.14.1/Redis-x64-5.0.14.1.zip' -OutFile 'infrastructure\redis-portable.zip'"
    mkdir "infrastructure\redis" 2>nul
    powershell -Command "Expand-Archive -Path 'infrastructure\redis-portable.zip' -DestinationPath 'infrastructure\redis' -Force"
    del /f "infrastructure\redis-portable.zip" 2>nul
    echo [INFO] Redis download completed.
) else (
    echo [INFO] Redis portable already exists.
)

echo [4/6] Copying files to release...

REM --- Copy backend services ---
xcopy /E /I /Y "backend-web" "%DIST_DIR%\backend-web" >nul
xcopy /E /I /Y "websocket" "%DIST_DIR%\websocket" >nul
xcopy /E /I /Y "scheduler" "%DIST_DIR%\scheduler" >nul
xcopy /E /I /Y "common" "%DIST_DIR%\common" >nul
xcopy /E /I /Y "frontend\dist" "%DIST_DIR%\frontend\dist" >nul

REM --- Copy promotion if exists ---
if "%HAS_PROMOTION%"=="1" (
    xcopy /E /I /Y "promotion\backend" "%DIST_DIR%\promotion\backend" >nul
    xcopy /E /I /Y "promotion\frontend\dist" "%DIST_DIR%\promotion\frontend\dist" >nul
)

REM --- Copy infrastructure ---
xcopy /E /I /Y "infrastructure\mysql\bin" "%DIST_DIR%\infrastructure\mysql\bin" >nul
if exist "infrastructure\mysql\share" xcopy /E /I /Y "infrastructure\mysql\share" "%DIST_DIR%\infrastructure\mysql\share" >nul
if exist "infrastructure\mysql\lib" xcopy /E /I /Y "infrastructure\mysql\lib" "%DIST_DIR%\infrastructure\mysql\lib" >nul
copy /Y "infrastructure\mysql\my.ini" "%DIST_DIR%\infrastructure\mysql\my.ini" >nul
xcopy /E /I /Y "infrastructure\redis" "%DIST_DIR%\infrastructure\redis" >nul

REM --- Copy scripts ---
copy /Y "start.bat" "%DIST_DIR%\start.bat" >nul
copy /Y "stop.bat" "%DIST_DIR%\stop.bat" >nul
mkdir "%DIST_DIR%\scripts" 2>nul
copy /Y "scripts\setup_embedded.py" "%DIST_DIR%\scripts\setup_embedded.py" >nul
copy /Y "scripts\frontend_server.py" "%DIST_DIR%\scripts\frontend_server.py" >nul

REM --- Copy Python runtime ---
for %%P in (python.exe) do set "PYTHON_DIR=%%~dp$PATH:P"
if defined PYTHON_DIR (
    copy /Y "%PYTHON_DIR%python.exe" "%DIST_DIR%\python.exe" >nul
    copy /Y "%PYTHON_DIR%pythonw.exe" "%DIST_DIR%\pythonw.exe" >nul 2>nul
    echo [INFO] Python runtime copied.
)

REM --- Install Playwright Chromium ---
set "PACKAGED_BROWSER_DIR=%DIST_DIR%\ms-playwright"
set "LOCAL_PW_BROWSERS=%LOCALAPPDATA%\ms-playwright"
set "PLAYWRIGHT_BROWSERS_PATH="
echo [INFO] Installing Playwright Chromium...
python -m playwright install chromium
if exist "%LOCAL_PW_BROWSERS%" (
    mkdir "%PACKAGED_BROWSER_DIR%" 2>nul
    xcopy /E /I /Y /Q "%LOCAL_PW_BROWSERS%" "%PACKAGED_BROWSER_DIR%" >nul
    echo [INFO] Playwright Chromium copied.
)

REM --- Install Python dependencies into dist ---
echo [INFO] Installing Python dependencies...
if exist "%DIST_DIR%\python.exe" (
    "%DIST_DIR%\python.exe" -m pip install --target "%DIST_DIR%\site-packages" fastapi uvicorn sqlalchemy pydantic pydantic-settings email-validator asyncmy pymysql redis aiohttp aiohttp-socks httpx loguru passlib python-jose[cryptography] pycryptodome websockets python-multipart Pillow anyio starlette click h11 sniffio idna certifi python-dateutil apscheduler python-socks[asyncio] requests qrcode openai bcrypt playwright 2>nul
    echo [INFO] Python dependencies installed.
) else (
    echo [WARN] python.exe not found in dist, skipping pip install.
)

echo [5/6] Cleaning sensitive files...
for %%S in (backend-web websocket scheduler) do (
    if exist "%DIST_DIR%\%%S\logs" rmdir /s /q "%DIST_DIR%\%%S\logs"
    if exist "%DIST_DIR%\%%S\.env" del /f "%DIST_DIR%\%%S\.env"
    if exist "%DIST_DIR%\%%S\.env.example" del /f "%DIST_DIR%\%%S\.env.example"
    if exist "%DIST_DIR%\%%S\pyproject.toml" del /f "%DIST_DIR%\%%S\pyproject.toml"
    if exist "%DIST_DIR%\%%S\static\uploads" rmdir /s /q "%DIST_DIR%\%%S\static\uploads"
)
if exist "%DIST_DIR%\websocket\browser_data" rmdir /s /q "%DIST_DIR%\websocket\browser_data"
if "%HAS_PROMOTION%"=="1" (
    if exist "%DIST_DIR%\promotion\backend\logs" rmdir /s /q "%DIST_DIR%\promotion\backend\logs"
    if exist "%DIST_DIR%\promotion\backend\.env" del /f "%DIST_DIR%\promotion\backend\.env"
    if exist "%DIST_DIR%\promotion\backend\.env.example" del /f "%DIST_DIR%\promotion\backend\.env.example"
    if exist "%DIST_DIR%\promotion\backend\pyproject.toml" del /f "%DIST_DIR%\promotion\backend\pyproject.toml"
)
for %%D in ("%DIST_DIR%\backend-web" "%DIST_DIR%\websocket" "%DIST_DIR%\scheduler" "%DIST_DIR%\common") do (
    for /d /r "%%~fD" %%C in (__pycache__) do if exist "%%~fC" rmdir /s /q "%%~fC"
    del /s /q "%%~fD\*.pyc" 2>nul
    del /s /q "%%~fD\*.pyo" 2>nul
    del /s /q "%%~fD\*.so" 2>nul
)
mkdir "%DIST_DIR%\logs" 2>nul
if exist "%DIST_DIR%\infrastructure\mysql\data" rmdir /s /q "%DIST_DIR%\infrastructure\mysql\data"
if exist "%DIST_DIR%\infrastructure\redis\appendonly.aof" del /f "%DIST_DIR%\infrastructure\redis\appendonly.aof" 2>nul
if exist "%DIST_DIR%\infrastructure\redis\dump.rdb" del /f "%DIST_DIR%\infrastructure\redis\dump.rdb" 2>nul

echo [6/6] Creating release zip...
set ZIP_NAME=app-v%APP_VER%.zip
if exist "release\%ZIP_NAME%" del /f "release\%ZIP_NAME%"
powershell -Command "Compress-Archive -Path 'release\XianyuAutoReply\*' -DestinationPath 'release\%ZIP_NAME%' -Force"
if errorlevel 1 (
    echo [ERROR] Failed to create zip package.
    goto :end
)

echo.
echo ============================================
echo   Build Complete!
echo   Output: release\XianyuAutoReply\
echo   Zip:    release\%ZIP_NAME%
echo   Run:    release\XianyuAutoReply\start.bat
echo ============================================
echo.
echo Notes:
echo   1. No Nuitka / Visual Studio required.
echo   2. Launch via start.bat (no activation code).
echo   3. Embedded MySQL + Redis included.
echo   4. Open http://localhost:9000 after startup.
echo.

:end
echo.
pause
