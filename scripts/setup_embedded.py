"""
嵌入式环境初始化脚本。
在 start.bat 中调用，负责：
1. 等待 MySQL/Redis 就绪
2. 创建 xianyu_data 数据库
3. 生成各服务的 .env 文件
"""
import socket
import sys
import time
from pathlib import Path

MYSQL_HOST = "127.0.0.1"
MYSQL_PORT = 3306
MYSQL_USER = "root"
MYSQL_PASSWORD = ""
MYSQL_DATABASE = "xianyu_data"

REDIS_HOST = "127.0.0.1"
REDIS_PORT = 6379
REDIS_PASSWORD = ""
REDIS_DB = 0

MAX_WAIT = 30


def wait_for_port(host: str, port: int, name: str, timeout: int = MAX_WAIT) -> bool:
    for i in range(timeout):
        try:
            with socket.create_connection((host, port), timeout=1):
                return True
        except (ConnectionRefusedError, OSError):
            if i == 0:
                print(f"[setup] 等待 {name} 启动 ({host}:{port})...")
            time.sleep(1)
    return False


def _mysql_connect():
    import pymysql
    for host in [MYSQL_HOST, "."]:
        try:
            conn = pymysql.connect(
                host=host,
                port=MYSQL_PORT,
                user=MYSQL_USER,
                password=MYSQL_PASSWORD,
                charset="utf8mb4",
            )
            return conn
        except Exception:
            continue
    return None


def create_database() -> bool:
    try:
        import pymysql
    except ImportError:
        print("[setup][ERROR] pymysql 未安装")
        return False

    for attempt in range(3):
        try:
            conn = _mysql_connect()
            if conn is None:
                raise RuntimeError("无法连接 MySQL")
            with conn.cursor() as cur:
                cur.execute(
                    f"CREATE DATABASE IF NOT EXISTS `{MYSQL_DATABASE}` "
                    "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
                )
            conn.commit()
            conn.close()
            print(f"[setup] 数据库 `{MYSQL_DATABASE}` 已就绪")
            return True
        except Exception as e:
            if attempt < 2:
                print(f"[setup] 数据库创建失败，重试中... ({e})")
                time.sleep(2)
            else:
                print(f"[setup][ERROR] 数据库创建失败: {e}")
                return False
    return False


def generate_env_files() -> bool:
    """直接生成各服务的 .env 文件"""
    project_root = Path(__file__).parent.parent
    ok = True
    for service_dir_name in ("backend-web", "websocket", "scheduler"):
        env_path = project_root / service_dir_name / ".env"
        env_content = _build_env_content(service_dir_name)
        try:
            env_path.write_text(env_content, encoding="utf-8")
            print(f"[setup] 已生成 {service_dir_name}/.env")
        except Exception as e:
            print(f"[setup][ERROR] 生成 {service_dir_name}/.env 失败: {e}")
            ok = False
    return ok


def _build_env_content(service_dir_name: str) -> str:
    base = f"""\
ENVIRONMENT=production
LOG_LEVEL=INFO

MYSQL_HOST={MYSQL_HOST}
MYSQL_PORT={MYSQL_PORT}
MYSQL_USER={MYSQL_USER}
MYSQL_PASSWORD={MYSQL_PASSWORD}
MYSQL_DATABASE={MYSQL_DATABASE}

REDIS_HOST={REDIS_HOST}
REDIS_PORT={REDIS_PORT}
REDIS_PASSWORD={REDIS_PASSWORD}
REDIS_DB={REDIS_DB}
"""
    if service_dir_name == "backend-web":
        base += """\
BACKEND_WEB_PORT=8089

JWT_SECRET_KEY=embedded-auto-generated-key-change-in-production
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_MINUTES=10080

CORS_ORIGINS=*

WEBSOCKET_SERVICE_URL=http://localhost:8090
SCHEDULER_SERVICE_URL=http://localhost:8091

STATIC_DIR=static
FRONTEND_PUBLIC_URL=http://localhost:9000
BACKEND_WEB_PUBLIC_URL=http://localhost:8089
AUTO_START_CRAWL_JOBS=false
"""
    elif service_dir_name == "websocket":
        base += """\
WEBSOCKET_PORT=8090
MAX_CAPTCHA_CONCURRENT=1
BROWSER_HEADLESS=true
TOKEN_REFRESH_INTERVAL=72000
TOKEN_RETRY_INTERVAL=7200
BACKEND_WEB_SERVICE_URL=http://localhost:8089
STATIC_DIR=static
"""
    elif service_dir_name == "scheduler":
        base += """\
SCHEDULER_PORT=8091
REDELIVERY_INTERVAL=5
RATE_INTERVAL=20
WEBSOCKET_SERVICE_URL=http://localhost:8090
BACKEND_WEB_SERVICE_URL=http://localhost:8089
STATIC_DIR=static
"""
    return base


def main() -> int:
    print("[setup] 开始初始化嵌入式环境...")

    if not wait_for_port(MYSQL_HOST, MYSQL_PORT, "MySQL"):
        print("[setup][ERROR] MySQL 启动超时")
        return 1

    if not wait_for_port(REDIS_HOST, REDIS_PORT, "Redis"):
        print("[setup][ERROR] Redis 启动超时")
        return 1

    if not create_database():
        return 1

    generate_env_files()

    print("[setup] 初始化完成")
    return 0


if __name__ == "__main__":
    sys.exit(main())
