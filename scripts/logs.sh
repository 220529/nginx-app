#!/bin/bash
# 查看 ERP Docker 服务日志
# 用法: ./logs.sh [服务名] [行数]
# 示例: ./logs.sh erp-core 100

APP_DIR="/app"

SERVICE="${1:-all}"
LINES="${2:-100}"

SERVICES=(
    "db-app"
    "erp-core"
    "erp-web"
    "nginx-app"
)

get_compose_file() {
    local service_dir="$APP_DIR/$1"
    if [ -f "$service_dir/docker-compose.prod.yml" ]; then
        echo "$service_dir/docker-compose.prod.yml"
    elif [ -f "$service_dir/docker-compose-prod.yml" ]; then
        echo "$service_dir/docker-compose-prod.yml"
    elif [ -f "$service_dir/docker-compose.yml" ]; then
        echo "$service_dir/docker-compose.yml"
    fi
}

show_logs() {
    local service=$1
    local compose_file=$(get_compose_file "$service")

    if [ -n "$compose_file" ]; then
        echo ""
        echo "=========================================="
        echo "  $service 日志 (最近 $LINES 行)"
        echo "=========================================="
        docker compose -f "$compose_file" logs --tail="$LINES" 2>/dev/null || echo "无法获取日志"
    else
        echo "未找到服务: $service"
    fi
}

if [ "$SERVICE" == "all" ]; then
    echo "用法: ./logs.sh [服务名] [行数]"
    echo ""
    echo "可用服务:"
    for s in "${SERVICES[@]}"; do
        echo "  - $s"
    done
    echo ""
    echo "示例:"
    echo "  ./logs.sh erp-core       # 查看 erp-core 最近 100 行日志"
    echo "  ./logs.sh nginx-app 200  # 查看 nginx-app 最近 200 行日志"
else
    show_logs "$SERVICE"
fi
