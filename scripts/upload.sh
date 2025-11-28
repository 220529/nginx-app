#!/bin/bash
# 上传 scripts 目录到服务器
# 用法: ./upload.sh [用户@服务器] [远程目录]
# 示例: ./upload.sh root@your-server.com /app/nginx-app

set -e

# 默认配置
DEFAULT_SERVER="root@47.93.17.251"
DEFAULT_REMOTE_DIR="/app/nginx-app"

SERVER="${1:-$DEFAULT_SERVER}"
REMOTE_DIR="${2:-$DEFAULT_REMOTE_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  上传 scripts 到服务器"
echo "=========================================="
echo ""
echo "本地目录: $SCRIPT_DIR"
echo "目标服务器: $SERVER"
echo "远程目录: $REMOTE_DIR/scripts"
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
echo "  ./start.sh    # 启动所有服务"
echo "  ./stop.sh     # 停止所有服务"
echo "  ./restart.sh  # 重启所有服务"
echo "  ./status.sh   # 查看服务状态"
echo "  ./logs.sh     # 查看日志"
