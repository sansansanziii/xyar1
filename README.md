# 闲鱼自动回复系统

本文档面向运维与部署人员，详细说明本项目的部署流程、依赖版本、环境变量、常用运维命令与故障排查方法。

## 交流群

| 微信群 | 微信群1 | QQ群 |
|:---:|:---:|:---:|
| ![微信群](https://github.com/zhinianboke/xianyu-auto-reply/blob/20260423_old/static/wechat-group.png?raw=true) | ![微信群1](https://github.com/zhinianboke/xianyu-auto-reply/blob/20260423_old/static/wechat-group1.png?raw=true) | ![QQ群](https://github.com/zhinianboke/xianyu-auto-reply/blob/20260423_old/static/qq-group.png?raw=true) |

---

## 目录

- [一、项目简介](#一项目简介)
- [二、Python 版本要求](#二python-版本要求重要)
- [三、部署方式总览](#三部署方式总览)
- [四、方式一：Docker 加密源码构建](#四方式一docker-加密源码构建推荐)
- [五、方式二：本地源码运行](#五方式二本地源码运行开发调试)
- [六、方式三：Windows EXE 打包](#六方式三windows-exe-打包)
- [七、推广返佣子系统](#七推广返佣子系统可选模块)
- [八、环境变量配置说明](#八环境变量配置说明)
- [九、常用运维命令](#九常用运维命令)
- [十、数据持久化与备份](#十数据持久化与备份)
- [十一、故障排查](#十一故障排查)
- [十二、安全建议](#十二安全建议)
- [十三、目录结构参考](#十三目录结构参考)
- [十四、版本与许可](#十四版本与许可)

---

## 一、项目简介

本项目是一个基于微服务架构的闲鱼自动回复与运营管理系统，由前端、Backend-Web、WebSocket、Scheduler、MySQL、Redis 共 6 个核心服务组成，支持 Docker Compose 一键部署，也支持 Windows EXE 单机打包运行。

### 1.1 服务拓扑

| 服务名 | 容器名 | 默认端口 | 说明 |
| --- | --- | --- | --- |
| `frontend` | `xianyu-frontend` | `9000` | 前端站点（Nginx + 前端构建产物） |
| `backend-web` | `xianyu-backend-web` | `8089` | 主业务后端（FastAPI） |
| `websocket` | `xianyu-websocket` | `8090` | 闲鱼 WebSocket 接入与浏览器自动化 |
| `scheduler` | `xianyu-scheduler` | `8091` | 定时任务（重发、限流统计等） |
| `mysql` | `xianyu-mysql` | 仅内网 `3306` | MySQL 8.0 |
| `redis` | `xianyu-redis` | 仅内网 `6379` | Redis 7（开启密码与 AOF） |

### 1.2 功能特性

#### 核心功能
- **智能自动回复**：通过 WebSocket 实时接入闲鱼 IM 消息，支持 AI（OpenAI）和关键词匹配两种回复模式
- **多账号管理**：支持管理多个闲鱼账号，通过 Cookie 或扫码登录
- **在线聊天**：WebSocket 实时在线聊天界面，支持人工介入

#### 运营功能
- **订单管理**：自动获取和管理闲鱼订单
- **商品管理**：商品信息管理、搜索、批量操作
- **自动发货**：卡密自动发货、自动确认收货
- **自动评价**：自动给买家好评
- **自动重新上架**：商品定时重发/擦亮
- **商品发布**：批量发布商品到闲鱼
- **Cookie 管理**：自动刷新 Cookie 保持登录状态

#### 管理功能
- **用户系统**：多用户、管理员/普通用户角色
- **激活码系统**：软件授权激活（含硬件绑定）
- **仪表盘**：数据统计和可视化
- **风险控制**：风控日志记录
- **公告/广告**：系统公告和广告位管理
- **通知系统**：消息通知渠道配置
- **验证码处理**：极验（Geetest）滑动验证码自动识别

#### 推广分销（可选）
- **淘宝联盟**：淘宝联盟推广集成
- **分销体系**：代理商、子代理商管理
- **对账结算**：资金流和结算管理

### 1.3 技术栈

| 层 | 技术 |
|----|------|
| 前端 | React 18 + TypeScript + Vite + Tailwind CSS + Zustand |
| 后端 | Python 3.11/3.12 + FastAPI + SQLAlchemy + Uvicorn |
| 数据库 | MySQL 8.0 + Redis 7 |
| 浏览器自动化 | Playwright (Chromium) |
| AI | OpenAI API |
| 消息接入 | WebSocket（闲鱼 IM） |
| 部署 | Docker Compose / Windows EXE（Nuitka） |
| 源码保护 | Cython 编译 |

### 1.4 核心仓库目录

| 目录 | 作用 |
| --- | --- |
| `backend-web/` | Backend-Web 服务源码与 `Dockerfile` |
| `websocket/` | WebSocket 服务源码与 `Dockerfile` |
| `scheduler/` | Scheduler 服务源码与 `Dockerfile` |
| `common/` | 跨服务共享的数据库、工具与服务模块 |
| `frontend/` | 主前端（React + Vite） |
| `promotion/` | 推广返佣子系统（可选模块，存在时自动启用） |
| `launcher/` | EXE 单机版统一启动器入口 |
| `docker/` | 前端镜像构建上下文 |
| `scripts/` | 辅助脚本（按端口停止服务等） |

---

## 二、Python 版本要求（重要）

不同部署方式对 Python 版本要求**不一样**，请严格按照下表选择：

| 部署方式 | Python 版本 | 说明 |
| --- | --- | --- |
| Docker 加密源码构建 | **不需要本机 Python** | 镜像内统一使用 Python 3.11 |
| 本地源码运行（Windows） | **必须 Python 3.12（64 位）** | 仓库内 `.pyd` 加密产物为 `cp312-win_amd64`，其它版本无法加载 |
| 本地源码运行（Linux） | **必须 Python 3.11** | 仓库内 `.so` 加密产物为 `cpython-311-x86_64-linux-gnu`，其它版本无法加载 |
| Windows EXE 打包 | **必须 Python 3.12（且为 64 位）** | 同上，打包时需加载 `.pyd` |
| Windows EXE 运行 | **无需安装 Python** | 打包脚本会把 `python.exe` 与 `Lib` 一起带入发布包 |

> **特别提醒**：Linux 容器使用的 `.so` 文件名是 `cpython-311-x86_64-linux-gnu.so`，因此 **Linux 容器内的 Python 必须是 3.11**。Dockerfile 已锁定 `python:3.11-slim`，请勿擅自升级到 3.12。

### 2.1 检查本机 Python 版本

Windows PowerShell：

```powershell
python --version
# 期望输出：Python 3.12.x
```

Linux / macOS：

```bash
python3 --version
```

---

## 三、部署方式总览

本项目提供 **3 种部署/运行方式**，请根据使用场景选择：

| 方式 | 适用场景 | 入口 |
| --- | --- | --- |
| 方式一：Docker 加密源码构建 | 生产/私有部署，源码加密 | 远程一键脚本 |
| 方式二：本地源码运行 | 本地开发调试，不依赖 Docker | 各服务 `main.py` / `启动.bat` |
| 方式三：Windows EXE 打包 | Windows 单机离线分发 | `EXE打包构建.bat` |

---

## 四、方式一：Docker 加密源码构建（推荐）

适用于私有部署、源码不便外发的场景，构建过程会对 Python 源码进行 **Cython 编译**，最终镜像内只保留 `.so` 二进制。

### 4.1 前置条件

| 项目 | 要求 |
| --- | --- |
| Docker | `>= 20.10` |
| Docker Compose | `>= 1.29` |
| 磁盘 | 至少 30 GB（编译过程占用较高） |
| 内存 | 建议 8 GB 以上（Cython 编译比较吃内存） |

### 4.2 部署步骤

#### 4.2.1 服务器一键部署（推荐）

服务器已安装 Docker 与 Docker Compose 后，直接执行加密版一键部署脚本即可：

```bash
curl -fsSL https://xy-update.zhinianboke.com/deploy_enc.sh | sed 's/\r$//' | bash
```

该脚本会自动完成加密版部署所需的配置生成、镜像构建、旧容器清理与服务启动。


更新版本，直接执行加密版一键更新脚本即可：
```bash
curl -fsSL https://xy-update.zhinianboke.com/update_enc.sh | sed 's/\r$//' | bash
```


---

## 五、方式二：本地源码运行（开发调试）

适用于本地开发调试场景，不依赖 Docker，直接在本机运行各服务。

### 5.1 环境要求

| 项目 | 要求 | 说明 |
|------|------|------|
| Python | Windows: **3.12**；Linux: **3.11** | 仓库内加密产物按平台锁定版本，不可混用 |
| Node.js | `>= 18`（带 `npm`） | 前端构建与开发 |
| MySQL | `8.0` | 需提前安装并启动 |
| Redis | `7.x` | 需提前安装并启动 |
| Playwright | 自动安装 | 首次运行需下载 Chromium |

### 5.2 准备数据库与 Redis

```sql
-- 登录 MySQL 创建数据库
CREATE DATABASE xianyu_data CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

确保 Redis 服务已启动，记下端口和密码。

### 5.3 配置环境变量

每个服务目录下都有 `.env.example`，复制为 `.env` 并修改：

```powershell
# 后端服务
Copy-Item backend-web\.env.example backend-web\.env
Copy-Item websocket\.env.example websocket\.env
Copy-Item scheduler\.env.example scheduler\.env
```

**必须修改的配置**（三个 `.env` 文件中保持一致）：

| 变量 | 说明 |
|------|------|
| `MYSQL_HOST` | MySQL 地址，本机一般为 `localhost` |
| `MYSQL_USER` | MySQL 用户名 |
| `MYSQL_PASSWORD` | MySQL 密码 |
| `MYSQL_DATABASE` | 数据库名，如 `xianyu_data` |
| `REDIS_HOST` | Redis 地址，本机一般为 `localhost` |
| `REDIS_PASSWORD` | Redis 密码（无密码留空） |
| `JWT_SECRET_KEY` | JWT 密钥，建议改为随机字符串 |

### 5.4 安装依赖

```powershell
# 后端依赖（三个服务分别安装）
cd backend-web; pip install -e .; cd ..
cd websocket; pip install -e .; cd ..
cd scheduler; pip install -e .; cd ..

# 安装 Playwright 浏览器（WebSocket 服务需要）
python -m playwright install chromium

# 前端依赖
cd frontend; npm install; cd ..
```

> 建议使用虚拟环境（`python -m venv .venv`）隔离依赖，避免污染全局 Python 环境。

### 5.5 启动服务

需要同时运行 **4 个进程**（后端 3 个 + 前端 1 个），建议使用 4 个终端窗口：

```powershell
# 终端 1：启动 Backend-Web（默认端口 8089）
cd backend-web
python main.py

# 终端 2：启动 WebSocket（默认端口 8090）
cd websocket
python main.py

# 终端 3：启动 Scheduler（默认端口 8091）
cd scheduler
python main.py

# 终端 4：启动前端开发服务器（默认端口 9000）
cd frontend
npm run dev
```

启动成功后访问：

```
http://localhost:9000
```

### 5.6 Windows 快捷启动

各服务目录下提供了 `启动.bat` 和 `停止.bat` 脚本，双击即可快速启停：

```
backend-web/启动.bat    # 启动 Backend-Web
backend-web/停止.bat    # 停止 Backend-Web
websocket/启动.bat      # 启动 WebSocket
scheduler/启动.bat      # 启动 Scheduler
frontend/启动.bat       # 启动前端
```

### 5.7 注意事项

- 前端开发服务器（`npm run dev`）会自动将 `/api` 请求代理到 `localhost:8089`，无需额外配置
- 三个后端服务的 `.env` 中数据库和 Redis 配置必须一致
- 首次启动后端服务会自动创建数据库表
- WebSocket 服务依赖 Playwright（Chromium），首次运行会自动下载浏览器

---

## 六、方式三：Windows EXE 打包

适用于 Windows 单机离线分发的场景，将整个系统打包成一个独立可执行目录。

### 6.1 打包机环境要求

| 项目 | 要求 | 备注 |
| --- | --- | --- |
| 操作系统 | Windows 10 / 11 或 Windows Server 2019 / 2022（64 位） | 必须 64 位 |
| **Python** | **必须 3.12.x（64 位）** | **不能是 3.11、3.13** |
| Node.js | `>= 18`（带 `npm`） | 用于构建前端 |
| Nuitka | 自动安装 | 脚本内会自动 `pip install nuitka ordered-set zstandard` |
| 磁盘 | 至少 15 GB 空闲 | Nuitka 编译与 Chromium 下载需要较大空间 |
| 网络 | 可访问 PyPI 与 Playwright 官方源 | 用于安装依赖与下载 Chromium |

### 6.2 安装 Python 3.12 的注意事项

1. 从 [python.org](https://www.python.org/downloads/release/python-3120/) 下载 **Windows installer (64-bit)**。
2. 安装时勾选 `Add python.exe to PATH`。
3. **务必**使用 64 位版本（仓库内的 `.pyd` 文件名为 `cp312-win_amd64`）。
4. 安装完成后在 PowerShell 中验证：

```powershell
python --version
# 必须输出：Python 3.12.x

python -c "import platform; print(platform.architecture())"
# 必须输出：('64bit', 'WindowsPE')
```

### 6.3 安装项目依赖（打包前）

EXE 打包脚本会调用 `python -m playwright install chromium`，因此需要先在打包机上安装项目依赖：

```powershell
# 在仓库根目录执行
python -m pip install --upgrade pip
python -m pip install playwright
python -m playwright install chromium

# 安装 Nuitka 打包脚本中 --include-package= 列出的运行时依赖
python -m pip install fastapi "uvicorn[standard]" sqlalchemy asyncmy pymysql `
    pydantic pydantic-settings email-validator aiohttp aiohttp-socks `
    "python-jose[cryptography]" "passlib[bcrypt]" bcrypt loguru httpx redis `
    pycryptodome requests python-dateutil pandas openpyxl websockets `
    python-multipart "qrcode[pil]" Pillow apscheduler "python-socks[asyncio]" `
    openai
```

> 项目使用 `pyproject.toml` 管理依赖，未提供 `requirements.txt`。上面的命令覆盖了打包脚本所需的全部第三方包。

### 6.4 一键打包

```powershell
# 在仓库根目录双击或在 PowerShell 中执行
.\EXE打包构建.bat
```

脚本会按 7 个步骤完成：

1. 清理旧的 `build_output/` 与 `release/` 目录
2. 构建主前端（`frontend/`），如存在则同时构建推广前端（`promotion/frontend/`）
3. 使用 Nuitka 将 `launcher/main.py` 编译为 `XianyuAutoReply.exe`
4. 复制各服务的加密产物（`.pyd`）、前端构建产物、`python.exe` 与标准库 `Lib` 到发布目录
5. 清理敏感与临时文件（`.env`、`.env.example`、`logs/`、`uploads/`、`browser_data/`、Linux `.so`、缓存等）
6. 生成 `release/XianyuAutoReply/` 目录
7. 压缩成 `release/app-v<版本号>.zip`

### 6.5 运行 EXE

```text
release\XianyuAutoReply\XianyuAutoReply.exe
```

EXE 启动器会自动拉起 `backend-web`、`websocket`、`scheduler` 三个服务以及内置前端。

> EXE 单机版**不包含 MySQL 与 Redis**，需自行连接外部 MySQL 与 Redis，连接信息在首次运行时由启动器引导填写或写入 `data/.env`。

---

## 七、推广返佣子系统（可选模块）

推广返佣子系统是一个独立的可选模块，用于淘宝联盟推广和分销管理。当 `promotion/` 目录存在时，Docker 部署会自动启用该模块。

### 7.1 服务端口

| 服务 | 默认端口 | 说明 |
|------|----------|------|
| 推广后端 | `8092` | 推广返佣 API 服务 |
| 推广前端 | 随主前端部署 | 通过主前端 Nginx 代理访问 |

### 7.2 环境变量

推广后端使用独立的 `.env` 文件（`promotion/backend/.env`），关键变量：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PROMOTION_PORT` | `8092` | 推广后端端口 |
| `MYSQL_HOST` | `localhost` | 数据库地址（Docker 部署时自动配置） |
| `MYSQL_DATABASE` | `xianyu_data` | 共享主业务数据库 |
| `JWT_SECRET_KEY` | `change-me` | **生产环境必改** |

### 7.3 功能模块

- **淘宝联盟**：推广商品搜索、推广规则管理
- **素材管理**：推广素材的增删改查
- **商品规则**：商品推广规则配置
- **发布规则**：自动发布推广内容的规则
- **删除规则**：推广内容的自动删除规则

---

## 八、环境变量配置说明

部署方式一/二/三均使用根目录的 `.env` 文件，关键变量如下：

### 8.1 数据库与缓存

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `MYSQL_ROOT_PASSWORD` | `xianyu@2026` | MySQL root 密码 |
| `MYSQL_DATABASE` | `xianyu_data` | 业务数据库名 |
| `MYSQL_USER` | `xianyu` | 业务数据库用户名 |
| `MYSQL_PASSWORD` | `xianyu@2026` | 业务数据库密码 |
| `REDIS_PASSWORD` | `xianyu@2026` | Redis 密码 |
| `REDIS_DB` | `0` | Redis 数据库编号 |

### 8.2 安全相关

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `JWT_SECRET_KEY` | `change-me-in-production-please` | **生产环境必改** |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `1440` | 访问令牌过期时间（分钟） |
| `REFRESH_TOKEN_EXPIRE_MINUTES` | `10080` | 刷新令牌过期时间（分钟） |

### 8.3 端口与镜像

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `FRONTEND_PORT` | `9000` | 前端对外端口 |
| `BACKEND_WEB_PORT` | `8089` | Backend-Web 对外端口 |
| `WEBSOCKET_PORT` | `8090` | WebSocket 对外端口 |
| `SCHEDULER_PORT` | `8091` | Scheduler 对外端口 |
| `IMAGE_REGISTRY` | `registry.cn-shanghai.aliyuncs.com/zhinian-software` | 镜像仓库地址 |
| `IMAGE_TAG` | `latest` | 镜像版本标签 |

### 8.4 业务参数

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `LOG_LEVEL` | `INFO` | 日志级别 |
| `REDELIVERY_INTERVAL` | `5` | 重发任务间隔（分钟） |
| `RATE_INTERVAL` | `20` | 限流统计间隔（分钟） |
| `MAX_CAPTCHA_CONCURRENT` | `3` | 验证码识别最大并发数 |

### 8.5 前端环境变量

前端使用独立的环境变量文件，位于 `frontend/` 目录下：

| 文件 | 用途 |
|------|------|
| `.env.development` | 开发环境配置（Vite dev server） |
| `.env.production` | 生产环境配置（构建时使用） |

前端通过 Vite 代理（`vite.config.ts`）将 API 请求转发到后端，开发环境下无需额外配置后端地址。

---

## 九、常用运维命令

以下命令在仓库根目录执行，假设使用 `docker compose` 插件，若使用独立的 `docker-compose` 命令请自行替换。

```bash
# 查看所有容器状态
docker compose -f docker-compose.yml --env-file .env ps

# 查看实时日志（全部）
docker compose -f docker-compose.yml --env-file .env logs -f --tail=200

# 查看单个服务日志
docker compose -f docker-compose.yml --env-file .env logs -f backend-web

# 重启单个服务
docker compose -f docker-compose.yml --env-file .env restart backend-web

# 停止所有服务
docker compose -f docker-compose.yml --env-file .env down

# 进入容器内部
docker exec -it xianyu-backend-web bash
docker exec -it xianyu-mysql mysql -uroot -p

# 查看容器资源使用
docker stats --no-stream
```

---

## 十、数据持久化与备份

Docker 部署使用以下命名卷持久化数据：

| 卷名 | 说明 |
| --- | --- |
| `mysql_data` | MySQL 数据文件 |
| `redis_data` | Redis AOF 文件 |
| `backend_web_logs` | Backend-Web 日志 |
| `websocket_logs` | WebSocket 日志 |
| `scheduler_logs` | Scheduler 日志 |
| `static-files` | 上传的静态文件（图片、二维码等） |
| `browser_data` | Playwright 浏览器配置 |

### 10.1 备份 MySQL

```bash
# 导出
docker exec xianyu-mysql sh -c \
  'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers xianyu_data' \
  > backup_$(date +%Y%m%d_%H%M%S).sql

# 恢复
docker exec -i xianyu-mysql sh -c \
  'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" xianyu_data' < backup_xxx.sql
```

### 10.2 备份静态文件

```bash
docker run --rm \
  -v xianyu-auto-reply_static-files:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/static_$(date +%Y%m%d).tar.gz -C /data .
```

---

## 十一、故障排查

### 11.1 容器启动失败

```bash
# 查看启动失败原因
docker compose -f docker-compose.yml --env-file .env logs <服务名>

# 查看容器退出码
docker ps -a | grep xianyu
```

常见原因：

| 现象 | 排查方向 |
| --- | --- |
| 容器反复重启 | `JWT_SECRET_KEY` 未配置、数据库连接失败、端口冲突 |
| `mysql` 健康检查不通过 | 数据卷权限问题、密码不一致（删卷重建或改密码） |
| `backend-web` 报 `Connection refused` | MySQL/Redis 还未启动完成，等 `start_period` 后再观察 |
| `websocket` 浏览器初始化失败 | Chromium 未安装、容器内存不足 |

### 11.2 端口冲突

修改 `.env` 中对应端口后重新部署：

```bash
sed -i 's/FRONTEND_PORT=9000/FRONTEND_PORT=9100/' .env
# 重新执行一键部署脚本
curl -fsSL https://xy-update.zhinianboke.com/deploy_enc.sh | sed 's/\r$//' | bash
```

### 11.3 镜像拉取失败

如果服务器无法访问阿里云镜像仓库，可改为方式二（本地源码运行）。

### 11.4 EXE 打包失败

| 报错信息 | 解决方案 |
| --- | --- |
| `Python was not found` | 安装 Python 3.12 并加入 PATH |
| `Current Python version is 3.x` | 换成 Python 3.12（脚本强校验） |
| `npm was not found` | 安装 Node.js 18+ |
| `Failed to install Nuitka` | 检查网络，或手动 `pip install nuitka ordered-set zstandard` |
| `Failed to install Chromium browser` | 检查 Playwright 网络，或单独执行 `python -m playwright install chromium` |

---

## 十二、安全建议

部署到公网前，请务必完成以下检查：

1. **修改所有默认密码**：`MYSQL_ROOT_PASSWORD`、`MYSQL_PASSWORD`、`REDIS_PASSWORD`。
2. **修改 `JWT_SECRET_KEY`**：建议使用 `openssl rand -hex 32` 生成的随机串。
3. **修改默认管理员密码**：首次登录后立即修改 `admin` 账号密码。
4. **限制端口暴露**：仅对外暴露 `9000`，`8089`/`8090`/`8091` 建议仅在内网可访问。
5. **启用 HTTPS**：建议在 `frontend` 前面加一层 Nginx 反向代理，配置 SSL 证书。
6. **定期备份**：参考第十节，建议每日备份 MySQL，每周备份静态文件。
7. **关闭多余防火墙端口**：仅放行 80/443/9000，`3306`/`6379` 严禁对公网开放。
8. **及时更新镜像**：定期执行一键部署脚本拉取最新版本。

---

## 十三、目录结构参考

```
xianyu-auto-reply/
├── README.md                       # 本文档
├── EXE打包构建.bat                 # Windows EXE 打包（方式三）
├── 启动.bat                        # 一键启动所有服务
├── 停止.bat                        # 一键停止所有服务
├── backend-web/                    # 主业务后端（FastAPI）
│   ├── Dockerfile                  # 加密版镜像（多阶段 Cython 编译）
│   ├── Dockerfile.local            # 源码版镜像
│   ├── main.py                     # 入口文件
│   ├── pyproject.toml              # Python >= 3.11
│   ├── .env.example                # 环境变量模板
│   ├── app/                        # 业务代码（含 .pyd/.so 编译产物）
│   │   ├── api/                    # API 路由层
│   │   ├── core/                   # 核心配置
│   │   └── services/               # 业务服务层
│   └── static/qrcode/              # 静态二维码图片
├── websocket/                      # WebSocket 服务（闲鱼消息接入）
│   ├── Dockerfile / Dockerfile.local
│   ├── main.py / pyproject.toml / .env.example
│   └── app/                        # 业务代码
├── scheduler/                      # 定时任务服务
│   ├── Dockerfile / Dockerfile.local
│   ├── main.py / pyproject.toml / .env.example
│   └── app/                        # 业务代码
├── common/                         # 跨服务共享模块
│   ├── core/                       # 核心配置
│   ├── db/                         # 数据库层
│   ├── models/                     # SQLAlchemy 数据模型
│   ├── schemas/                    # Pydantic 数据模式
│   ├── services/                   # 共享业务服务
│   └── utils/                      # 工具函数
├── frontend/                       # 主前端（React + Vite + TypeScript）
│   ├── package.json / vite.config.ts
│   ├── .env.development            # 开发环境配置
│   ├── .env.production             # 生产环境配置
│   ├── public/                     # 静态资源
│   └── src/                        # 源代码
│       ├── api/                    # API 调用层
│       ├── components/             # UI 组件
│       ├── pages/                  # 页面组件
│       ├── store/                  # 状态管理（Zustand）
│       ├── styles/                 # CSS 样式
│       ├── types/                  # TypeScript 类型
│       └── utils/                  # 工具函数
├── promotion/                      # 推广返佣子系统（可选）
│   ├── backend/                    # 推广后端（默认端口 8092）
│   │   ├── main.py / pyproject.toml / .env.example
│   │   └── app/                    # 业务代码
│   └── frontend/                   # 推广前端（React + Vite）
│       ├── package.json
│       └── src/                    # TypeScript 源码
├── launcher/                       # EXE 启动器入口
│   ├── main.py                     # 入口文件
│   └── （gui, activation, updater 等已编译模块）
├── docker/frontend/                # 前端镜像构建上下文
│   ├── Dockerfile
│   └── nginx.conf
└── scripts/
    └── stop_service_by_port.bat    # 按端口停止服务脚本
```

---

## 十四、版本与许可

- 当前版本：见 `launcher/version.py` 中的 `CURRENT_VERSION`。
- 许可：内部使用，请勿外传。

如有问题请联系运维团队。