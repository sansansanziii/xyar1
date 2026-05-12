@echo off
REM === XianyuAutoReply EXE build script ===
REM Builds frontend assets, compiles launcher with Nuitka, copies encrypted services,
REM cleans sensitive files, and creates release zip.
REM Original source directories are not modified.
chcp 65001 >nul
cd /d "%~dp0"
REM --- Force MSVC cl.exe to output English and Python subprocesses to UTF-8 ---
REM --- Without these, Nuitka's Scons backend crashes with UnicodeDecodeError ---
REM --- on Chinese Windows when compiling huge generated modules such as ---
REM --- playwright._generated and pyasn1.codec.ber.decoder. ---
set "VSLANG=1033"
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
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
for /f %%a in ('python -c "import sys; print(sys.version_info[0], sys.version_info[1], sep=chr(46))"') do set PY_VER=%%a
if not "%PY_VER%"=="3.12" (
    echo [ERROR] Current Python version is %PY_VER%. This project requires Python 3.12 because Windows .pyd files are cp312.
    goto :end
)

REM --- Check node/npm ---
call npm --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] npm was not found. Please install Node.js first.
    goto :end
)

REM --- Check Nuitka ---
python -c "import nuitka" 2>nul
if errorlevel 1 (
    echo [INFO] Installing Nuitka...
    pip install nuitka ordered-set zstandard
    if errorlevel 1 (
        echo [ERROR] Failed to install Nuitka.
        goto :end
    )
)

REM --- Read version from launcher.version ---
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
        echo [INFO] Promotion module detected and will be included.
    )
)

echo [1/9] Cleaning old build output...
if exist "build_output" rmdir /s /q "build_output"
if exist "release" rmdir /s /q "release"
mkdir release 2>nul

echo [2/9] Building main frontend...
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
    echo [ERROR] Main frontend output was not found: frontend\dist\index.html
    goto :end
)
echo [INFO] Main frontend build completed.

REM --- Build promotion frontend if it exists ---
if "%HAS_PROMOTION%"=="1" (
    echo [2.1/9] Building promotion frontend...
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
    if not exist "promotion\frontend\dist\index.html" (
        echo [ERROR] Promotion frontend output was not found.
        goto :end
    )
    echo [INFO] Promotion frontend build completed.
)

echo [3/9] Compiling launcher with Nuitka. This may take more than 10 minutes...
python -m nuitka ^
    --standalone ^
    --windows-console-mode=disable ^
    --windows-company-name=XianyuAutoReply ^
    --windows-product-name=XianyuAutoReply ^
    --windows-product-version=%APP_VER%.0 ^
    --windows-file-version=%APP_VER%.0 ^
    --output-filename=XianyuAutoReply.exe ^
    --output-dir=build_output ^
    --include-package=launcher ^
    --include-package=common ^
    --include-package=playwright ^
    --include-package-data=playwright ^
    --include-package=uvicorn ^
    --include-package=fastapi ^
    --include-package=sqlalchemy ^
    --include-package=pydantic ^
    --include-package=pydantic_settings ^
    --include-package=email_validator ^
    --include-package=asyncmy ^
    --include-package=pymysql ^
    --include-package=redis ^
    --include-package=aiohttp ^
    --include-package=aiohttp_socks ^
    --include-package=httpx ^
    --include-package=httpcore ^
    --include-package=loguru ^
    --include-package=passlib ^
    --include-package=jose ^
    --include-package=Crypto ^
    --include-package=websockets ^
    --include-package=multipart ^
    --include-package=PIL ^
    --include-package=anyio ^
    --include-package=starlette ^
    --include-package=click ^
    --include-package=h11 ^
    --include-package=sniffio ^
    --include-package=idna ^
    --include-package=certifi ^
    --include-package=dateutil ^
    --include-package=apscheduler ^
    --include-package=python_socks ^
    --include-package=requests ^
    --include-package=qrcode ^
    --include-package=openai ^
    --include-package=bcrypt ^
    --nofollow-import-to=test ^
    --nofollow-import-to=docs ^
    --nofollow-import-to=setuptools ^
    --nofollow-import-to=pip ^
    --nofollow-import-to=wheel ^
    --nofollow-import-to=nuitka ^
    --include-module=tkinter.ttk ^
    --include-module=tkinter.messagebox ^
    --enable-plugin=tk-inter ^
    --assume-yes-for-downloads launcher\main.py

if errorlevel 1 (
    echo.
    echo [ERROR] Nuitka compilation failed. Please check the errors above.
    goto :end
)

echo [4/9] Copying project files to dist...
set DIST_DIR=build_output\main.dist

REM --- Copy backend services and shared modules ---
xcopy /E /I /Y "backend-web" "%DIST_DIR%\backend-web" >nul
xcopy /E /I /Y "websocket" "%DIST_DIR%\websocket" >nul
xcopy /E /I /Y "scheduler" "%DIST_DIR%\scheduler" >nul
xcopy /E /I /Y "common" "%DIST_DIR%\common" >nul
xcopy /E /I /Y "frontend\dist" "%DIST_DIR%\frontend\dist" >nul

REM --- Make sure plain .py files in launcher (not Cython-encrypted) are also present in dist ---
REM --- so cython-built .pyd modules can resolve `from launcher.version import CURRENT_VERSION` ---
REM --- via launcher.__path__ when Nuitka's frozen finder is bypassed by extension imports. ---
if not exist "%DIST_DIR%\launcher" mkdir "%DIST_DIR%\launcher" 2>nul
if exist "launcher\__init__.py" copy /Y "launcher\__init__.py" "%DIST_DIR%\launcher\__init__.py" >nul
if exist "launcher\version.py" copy /Y "launcher\version.py" "%DIST_DIR%\launcher\version.py" >nul

REM --- Copy promotion module if it exists ---
if "%HAS_PROMOTION%"=="1" (
    xcopy /E /I /Y "promotion\backend" "%DIST_DIR%\promotion\backend" >nul
    xcopy /E /I /Y "promotion\frontend\dist" "%DIST_DIR%\promotion\frontend\dist" >nul
    echo [INFO] Promotion module copied.
)

REM =============================================
REM [4.5/9] 准备嵌入式 MySQL 和 Redis
REM =============================================
echo [4.5/9] Preparing embedded MySQL and Redis...

set "INFRA_DIR=%~dp0infrastructure"
set "MYSQL_ZIP_URL=https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-8.0.42-winx64.zip"
set "REDIS_ZIP_URL=https://github.com/tporadowski/redis/releases/download/v5.0.14.1/Redis-x64-5.0.14.1.zip"
set "MYSQL_ZIP=%INFRA_DIR%\mysql-portable.zip"
set "REDIS_ZIP=%INFRA_DIR%\redis-portable.zip"

REM --- 下载 MySQL 免安装版 ---
if not exist "%INFRA_DIR%\mysql\bin\mysqld.exe" (
    echo [INFO] Downloading MySQL portable...
    if not exist "%MYSQL_ZIP%" (
        powershell -Command "Invoke-WebRequest -Uri '%MYSQL_ZIP_URL%' -OutFile '%MYSQL_ZIP%'"
        if errorlevel 1 (
            echo [ERROR] Failed to download MySQL.
            goto :end
        )
    )
    echo [INFO] Extracting MySQL...
    powershell -Command "Expand-Archive -Path '%MYSQL_ZIP%' -DestinationPath '%INFRA_DIR%' -Force"
    REM 将 mysql-8.x-winx64 重命名为 mysql
    for /d %%D in ("%INFRA_DIR%\mysql-*") do (
        if exist "%INFRA_DIR%\mysql" rmdir /s /q "%INFRA_DIR%\mysql"
        move "%%~fD" "%INFRA_DIR%\mysql" >nul
    )
    del /f "%MYSQL_ZIP%" 2>nul
    echo [INFO] MySQL portable ready.
) else (
    echo [INFO] MySQL portable already exists, skipping download.
)

REM --- 下载 Redis Windows 版 ---
if not exist "%INFRA_DIR%\redis\redis-server.exe" (
    echo [INFO] Downloading Redis for Windows...
    if not exist "%REDIS_ZIP%" (
        powershell -Command "Invoke-WebRequest -Uri '%REDIS_ZIP_URL%' -OutFile '%REDIS_ZIP%'"
        if errorlevel 1 (
            echo [ERROR] Failed to download Redis.
            goto :end
        )
    )
    echo [INFO] Extracting Redis...
    if exist "%INFRA_DIR%\redis" rmdir /s /q "%INFRA_DIR%\redis"
    mkdir "%INFRA_DIR%\redis" 2>nul
    powershell -Command "Expand-Archive -Path '%REDIS_ZIP%' -DestinationPath '%INFRA_DIR%\redis' -Force"
    del /f "%REDIS_ZIP%" 2>nul
    echo [INFO] Redis portable ready.
) else (
    echo [INFO] Redis portable already exists, skipping download.
)

REM --- 复制 infrastructure 到 dist ---
echo [INFO] Copying infrastructure to dist...
xcopy /E /I /Y "infrastructure\mysql\bin" "%DIST_DIR%\infrastructure\mysql\bin" >nul
xcopy /E /I /Y "infrastructure\mysql\share" "%DIST_DIR%\infrastructure\mysql\share" >nul 2>nul
if exist "infrastructure\mysql\lib" xcopy /E /I /Y "infrastructure\mysql\lib" "%DIST_DIR%\infrastructure\mysql\lib" >nul 2>nul
copy /Y "infrastructure\mysql\my.ini" "%DIST_DIR%\infrastructure\mysql\my.ini" >nul
xcopy /E /I /Y "infrastructure\redis" "%DIST_DIR%\infrastructure\redis" >nul
REM 不要复制 MySQL data 目录（首次运行时自动初始化）
if exist "%DIST_DIR%\infrastructure\mysql\data" rmdir /s /q "%DIST_DIR%\infrastructure\mysql\data"
REM 删除 Redis 数据文件（首次运行时自动创建）
if exist "%DIST_DIR%\infrastructure\redis\appendonly.aof" del /f "%DIST_DIR%\infrastructure\redis\appendonly.aof" 2>nul
if exist "%DIST_DIR%\infrastructure\redis\dump.rdb" del /f "%DIST_DIR%\infrastructure\redis\dump.rdb" 2>nul

REM --- 复制启动/停止脚本 ---
copy /Y "start.bat" "%DIST_DIR%\start.bat" >nul
copy /Y "stop.bat" "%DIST_DIR%\stop.bat" >nul
copy /Y "scripts\setup_embedded.py" "%DIST_DIR%\scripts\setup_embedded.py" >nul

echo [INFO] Infrastructure and scripts copied to dist.

REM --- Copy python.exe and pythonw.exe to dist ---
for %%P in (python.exe) do (
    set "PYTHON_DIR=%%~dp$PATH:P"
)
if not exist "%DIST_DIR%\python.exe" (
    if exist "%PYTHON_DIR%python.exe" (
        copy /Y "%PYTHON_DIR%python.exe" "%DIST_DIR%\python.exe" >nul
        echo [INFO] python.exe copied to dist.
    ) else (
        echo [WARN] python.exe was not found. Playwright fallback installation may fail.
    )
)
if not exist "%DIST_DIR%\pythonw.exe" (
    if exist "%PYTHON_DIR%pythonw.exe" (
        copy /Y "%PYTHON_DIR%pythonw.exe" "%DIST_DIR%\pythonw.exe" >nul
        echo [INFO] pythonw.exe copied to dist.
    ) else (
        echo [WARN] pythonw.exe was not found. Service processes may show console windows.
    )
)

REM --- Copy Python standard library for the bundled python.exe ---
if defined PYTHON_DIR (
    if not exist "%DIST_DIR%\Lib\encodings" (
        if exist "%PYTHON_DIR%Lib" (
            echo [INFO] Copying Python standard library...
            xcopy /E /I /Y /Q "%PYTHON_DIR%Lib" "%DIST_DIR%\Lib" >nul
            echo [INFO] Python standard library copied.
        ) else (
            echo [WARN] Python Lib directory was not found at %PYTHON_DIR%Lib.
        )
    )
)

REM --- Install Chromium first to LOCAL user cache, then copy to dist. ---
REM --- Strategy: keep PLAYWRIGHT_BROWSERS_PATH unset so `playwright install` ---
REM --- uses the default LOCALAPPDATA\ms-playwright cache. This way the cache ---
REM --- persists across rebuilds and the next build can skip the slow CDN download. ---
set "PACKAGED_BROWSER_DIR=%DIST_DIR%\ms-playwright"
set "LOCAL_PW_BROWSERS=%LOCALAPPDATA%\ms-playwright"

REM --- Make sure no stale env var leaks from a previous step ---
set "PLAYWRIGHT_BROWSERS_PATH="

echo [INFO] Ensuring Chromium is installed in local cache (%LOCAL_PW_BROWSERS%)...
python -m playwright install chromium
if errorlevel 1 (
    echo [ERROR] Failed to install Chromium browser into local cache.
    goto :end
)

if not exist "%LOCAL_PW_BROWSERS%" (
    echo [ERROR] Local Playwright cache not found after install: %LOCAL_PW_BROWSERS%
    goto :end
)

echo [INFO] Copying Playwright browsers from local cache to package directory...
mkdir "%PACKAGED_BROWSER_DIR%" 2>nul
xcopy /E /I /Y /Q "%LOCAL_PW_BROWSERS%" "%PACKAGED_BROWSER_DIR%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy Playwright browsers into package directory.
    goto :end
)
echo [INFO] Playwright browsers ready in: %PACKAGED_BROWSER_DIR%

echo [5/9] Cleaning sensitive and temporary files...

REM --- Clean sensitive and temporary files from services ---
for %%S in (backend-web websocket scheduler) do (
    if exist "%DIST_DIR%\%%S\logs" rmdir /s /q "%DIST_DIR%\%%S\logs"
    if exist "%DIST_DIR%\%%S\.env" del /f "%DIST_DIR%\%%S\.env"
    if exist "%DIST_DIR%\%%S\.env.example" del /f "%DIST_DIR%\%%S\.env.example"
    if exist "%DIST_DIR%\%%S\pyproject.toml" del /f "%DIST_DIR%\%%S\pyproject.toml"
    if exist "%DIST_DIR%\%%S\static\uploads" rmdir /s /q "%DIST_DIR%\%%S\static\uploads"
)
if exist "%DIST_DIR%\websocket\browser_data" rmdir /s /q "%DIST_DIR%\websocket\browser_data"

REM --- Clean promotion files if the module exists ---
if "%HAS_PROMOTION%"=="1" (
    if exist "%DIST_DIR%\promotion\backend\logs" rmdir /s /q "%DIST_DIR%\promotion\backend\logs"
    if exist "%DIST_DIR%\promotion\backend\.env" del /f "%DIST_DIR%\promotion\backend\.env"
    if exist "%DIST_DIR%\promotion\backend\.env.example" del /f "%DIST_DIR%\promotion\backend\.env.example"
    if exist "%DIST_DIR%\promotion\backend\pyproject.toml" del /f "%DIST_DIR%\promotion\backend\pyproject.toml"
    if exist "%DIST_DIR%\promotion\backend\static\uploads" rmdir /s /q "%DIST_DIR%\promotion\backend\static\uploads"
    REM --- Remove promotion frontend source files and keep dist only ---
    if exist "%DIST_DIR%\promotion\frontend\src" rmdir /s /q "%DIST_DIR%\promotion\frontend\src"
    if exist "%DIST_DIR%\promotion\frontend\node_modules" rmdir /s /q "%DIST_DIR%\promotion\frontend\node_modules"
    if exist "%DIST_DIR%\promotion\frontend\package.json" del /f "%DIST_DIR%\promotion\frontend\package.json"
    if exist "%DIST_DIR%\promotion\frontend\package-lock.json" del /f "%DIST_DIR%\promotion\frontend\package-lock.json"
)

REM --- Clean caches and Linux-only binaries ---
for %%D in ("%DIST_DIR%\backend-web" "%DIST_DIR%\websocket" "%DIST_DIR%\scheduler" "%DIST_DIR%\common") do (
    for /d /r "%%~fD" %%C in (__pycache__) do (
        if exist "%%~fC" rmdir /s /q "%%~fC"
    )
    del /s /q "%%~fD\*.pyc" 2>nul
    del /s /q "%%~fD\*.pyo" 2>nul
    del /s /q "%%~fD\*.so" 2>nul
    if exist "%%~fD\.pytest_cache" rmdir /s /q "%%~fD\.pytest_cache"
    if exist "%%~fD\.mypy_cache" rmdir /s /q "%%~fD\.mypy_cache"
    if exist "%%~fD\temp" rmdir /s /q "%%~fD\temp"
    if exist "%%~fD\tmp" rmdir /s /q "%%~fD\tmp"
)
REM --- Clean promotion backend caches ---
if "%HAS_PROMOTION%"=="1" (
    for /d /r "%DIST_DIR%\promotion\backend" %%C in (__pycache__) do (
        if exist "%%~fC" rmdir /s /q "%%~fC"
    )
    del /s /q "%DIST_DIR%\promotion\backend\*.pyc" 2>nul
    del /s /q "%DIST_DIR%\promotion\backend\*.pyo" 2>nul
    del /s /q "%DIST_DIR%\promotion\backend\*.so" 2>nul
)

echo [6/9] Creating release directory...
xcopy /E /I /Y "%DIST_DIR%" "release\XianyuAutoReply" >nul
if not exist "release\XianyuAutoReply\logs" mkdir "release\XianyuAutoReply\logs" >nul

REM --- Ensure compiled EXE exists in release ---
if exist "%DIST_DIR%\XianyuAutoReply.exe" (
    copy /Y "%DIST_DIR%\XianyuAutoReply.exe" "release\XianyuAutoReply\XianyuAutoReply.exe" >nul
    echo [INFO] EXE verified in release directory.
) else if exist "build_output\XianyuAutoReply.exe" (
    copy /Y "build_output\XianyuAutoReply.exe" "release\XianyuAutoReply\XianyuAutoReply.exe" >nul
    echo [INFO] EXE copied from build_output to release directory.
) else (
    echo [ERROR] Compiled EXE was not found.
    goto :end
)

REM --- Remove user data directory from release ---
if exist "release\XianyuAutoReply\data" rmdir /s /q "release\XianyuAutoReply\data"

echo [7/9] Creating release zip...
set ZIP_NAME=app-v%APP_VER%.zip
if exist "release\%ZIP_NAME%" del /f "release\%ZIP_NAME%"

REM --- Compress release directory without extra parent layer ---
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
echo   Run:    release\XianyuAutoReply\start.bat  (一键启动)
echo   Or:     release\XianyuAutoReply\XianyuAutoReply.exe
echo ============================================
echo.
echo Notes:
echo   1. Original source directories were not modified.
echo   2. Encrypted business code is packaged as-is.
echo   3. Launcher was compiled to native EXE by Nuitka.
echo   4. Entry stubs are retained for service startup.
echo   5. Promotion module is included automatically when it exists.
echo   6. Embedded MySQL + Redis are included (start.bat 一键启动).
echo   7. release\%ZIP_NAME% can be uploaded to the update server.
echo.

:end
echo.
echo Press any key to exit...
pause >nul