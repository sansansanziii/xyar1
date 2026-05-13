"""
前端静态服务器 + API 反向代理。
替代 launcher 的 FrontendHandler，提供：
- 静态文件服务（frontend/dist）
- /api/* 代理到 backend-web (8089)
- /ws/*  代理到 websocket  (8090)
"""
import os
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse
import urllib.request
import urllib.error

FRONTEND_DIR = Path(__file__).parent.parent / "frontend" / "dist"
BACKEND_WEB = "http://localhost:8089"
WEBSOCKET_SVC = "http://localhost:8090"
PORT = 9000


class ProxyHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(FRONTEND_DIR), **kwargs)

    def do_GET(self):
        if self.path.startswith("/api/"):
            self._proxy(BACKEND_WEB)
        elif self.path.startswith("/ws/"):
            self._proxy(WEBSOCKET_SVC)
        else:
            # SPA: 非 /api 路径尝试静态文件，404 则返回 index.html
            if not self.path.startswith("/api") and not self._static_exists():
                self.path = "/index.html"
            super().do_GET()

    def do_POST(self):
        if self.path.startswith("/api/"):
            self._proxy(BACKEND_WEB)
        else:
            self._proxy(BACKEND_WEB)

    def do_PUT(self):
        self._proxy(BACKEND_WEB)

    def do_DELETE(self):
        self._proxy(BACKEND_WEB)

    def do_OPTIONS(self):
        self.send_response(200)
        self._set_cors_headers()
        self.end_headers()

    def _static_exists(self) -> bool:
        """检查静态文件是否存在"""
        clean = self.path.split("?")[0]
        path = FRONTEND_DIR / clean.lstrip("/")
        return path.is_file()

    def _proxy(self, target: str):
        """反向代理请求到目标服务"""
        target_url = target + self.path
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length) if content_length > 0 else None

            req = urllib.request.Request(
                target_url,
                data=body,
                method=self.command,
                headers={
                    k: v
                    for k, v in self.headers.items()
                    if k.lower() not in ("host", "connection")
                },
            )

            with urllib.request.urlopen(req, timeout=60) as resp:
                self.send_response(resp.status)
                for key, val in resp.getheaders():
                    if key.lower() not in ("transfer-encoding", "connection"):
                        self.send_header(key, val)
                self._set_cors_headers()
                self.end_headers()
                self.wfile.write(resp.read())

        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self._set_cors_headers()
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self._set_cors_headers()
            self.end_headers()
            self.wfile.write(f"Proxy error: {e}".encode())

    def _set_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")

    def log_message(self, format, *args):
        pass  # 静默日志


if __name__ == "__main__":
    if not FRONTEND_DIR.exists():
        print(f"[前端] 错误：前端目录不存在 {FRONTEND_DIR}")
        sys.exit(1)

    os.chdir(str(FRONTEND_DIR))
    server = HTTPServer(("0.0.0.0", PORT), ProxyHandler)
    print(f"[前端] 服务已启动: http://localhost:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("[前端] 已停止")
        server.server_close()
