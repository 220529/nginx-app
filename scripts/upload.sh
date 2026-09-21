#!/usr/bin/env bash
# Upload the local operational scripts to a server.
# Usage: ./upload.sh user@server [remote-directory]

set -Eeuo pipefail

DEFAULT_REMOTE_DIR="/app/nginx-app"

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 user@server [remote-directory]" >&2
    exit 2
fi

SERVER="$1"
REMOTE_DIR="${2:-$DEFAULT_REMOTE_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  Upload Nginx scripts to server"
echo "=========================================="
echo ""
echo "本地目录: $SCRIPT_DIR"
echo "Target server: $SERVER"
echo "Remote directory: $REMOTE_DIR/scripts"
echo ""

# 确认
read -p "确认上传? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "已取消"
    exit 0
fi

# 创建远程目录（如果不存在）
echo ""
echo "创建远程目录..."
ssh "$SERVER" "mkdir -p $REMOTE_DIR/scripts"

# 上传脚本
echo "上传脚本文件..."
scp -r "$SCRIPT_DIR"/* "$SERVER:$REMOTE_DIR/scripts/"

# 设置执行权限
echo "设置执行权限..."
ssh "$SERVER" "chmod +x $REMOTE_DIR/scripts/*.sh"

echo ""
echo "=========================================="
echo "  上传完成"
echo "=========================================="
echo ""
echo "在服务器上使用:"
echo "  cd $REMOTE_DIR/scripts"
echo "  ./start.sh    # 启动 Nginx"
echo "  ./stop.sh     # 停止 Nginx"
echo "  ./restart.sh  # reload Nginx"
echo "  ./status.sh   # 查看状态"
echo "  ./logs.sh     # 查看 Nginx 日志"
