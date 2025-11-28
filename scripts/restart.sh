#!/bin/bash
# 重启所有 ERP Docker 服务
# 服务目录: /app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  重启所有 ERP Docker 服务"
echo "=========================================="

# 先停止所有服务
echo ""
echo ">>> 第一步: 停止所有服务"
bash "$SCRIPT_DIR/stop.sh"

# 等待一下确保服务完全停止
sleep 2

# 再启动所有服务
echo ""
echo ">>> 第二步: 启动所有服务"
bash "$SCRIPT_DIR/start.sh"

echo ""
echo "=========================================="
echo "  重启完成"
echo "=========================================="
