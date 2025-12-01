#!/bin/bash
# 停止所有 ERP Docker 服务
# 服务目录: /app

set -e

APP_DIR="/app"

# 服务列表（按停止顺序）
SERVICES=(
    "nginx-app"
    "erp-web"
    "erp-core"
    "db-app"
)

echo "=========================================="
echo "  停止所有 ERP Docker 服务"
echo "=========================================="

for service in "${SERVICES[@]}"; do
    service_dir="$APP_DIR/$service"
    compose_file=""

    # 查找 compose 文件
    if [ -f "$service_dir/docker-compose.prod.yml" ]; then
        compose_file="$service_dir/docker-compose.prod.yml"
    elif [ -f "$service_dir/docker-compose-prod.yml" ]; then
        compose_file="$service_dir/docker-compose-prod.yml"
    elif [ -f "$service_dir/docker-compose.yml" ]; then
        compose_file="$service_dir/docker-compose.yml"
    fi

    if [ -n "$compose_file" ]; then
        echo ""
        echo "正在停止 $service ..."
        docker compose -f "$compose_file" down || echo "警告: $service 停止失败"
    else
        echo "跳过 $service: 未找到 compose 文件"
    fi
done

echo ""
echo "=========================================="
echo "  所有服务已停止"
echo "=========================================="
echo ""
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
