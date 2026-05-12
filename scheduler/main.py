"""Scheduler服务启动入口（最小桩，业务逻辑见 _bootstrap.py）"""
from __future__ import annotations

import sys
from pathlib import Path

# 将当前目录和项目根目录添加到 Python 路径（必须先于业务导入）
current_dir = Path(__file__).parent
project_root = current_dir.parent
sys.path.insert(0, str(current_dir))
sys.path.insert(0, str(project_root))

from _bootstrap import app  # noqa: E402

if __name__ == "__main__":
    from _bootstrap import run_server
    run_server()
