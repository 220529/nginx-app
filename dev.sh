#!/bin/bash

# 提示用户选择操作
echo "请选择操作:"
echo "1. 停止"
echo "2. 启动"

# 读取用户输入
read -p "输入选项 (1 或 2): " choice

# 根据用户选择执行相应的命令
case $choice in
    1)
        echo "正在停止服务..."
        docker compose -f docker-compose-prod.yml down
        ;;
    2)
        echo "正在启动服务..."
        docker compose -f docker-compose-prod.yml up -d
        ;;
    *)
        echo "无效选项，请输入 1 或 2。"
        ;;
esac
