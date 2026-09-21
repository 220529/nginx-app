#!/usr/bin/env bash

# Convenience wrapper for the host Nginx scripts.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "请选择操作:"
echo "1. 停止 Nginx"
echo "2. 启动 Nginx"
echo "3. reload Nginx"
echo "4. 查看状态"
read -r -p "输入选项 (1-4): " choice

case "$choice" in
    1) bash "$SCRIPT_DIR/scripts/stop.sh" ;;
    2) bash "$SCRIPT_DIR/scripts/start.sh" ;;
    3) bash "$SCRIPT_DIR/scripts/restart.sh" ;;
    4) bash "$SCRIPT_DIR/scripts/status.sh" ;;
    *) echo "无效选项，请输入 1-4。" >&2; exit 2 ;;
esac
