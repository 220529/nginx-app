#!/bin/bash
# 查看所有 ERP Docker 服务状态
# 服务目录: /app

APP_DIR="/app"

SERVICES=(
    "db-app"
    "erp-core"
    "erp-web"
    "nginx-app"
)

echo "=========================================="
echo "  ERP Docker 服务状态"
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
        echo ">>> $service"
        docker compose -f "$compose_file" ps 2>/dev/null || echo "  未运行"
    fi
done

echo ""
echo "=========================================="
echo "  所有 Docker 容器"
echo "=========================================="
echo ""
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
