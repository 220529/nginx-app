#!/bin/bash
# SSL 证书自动续期脚本
# 通过 cron 定时执行

set -e

LOG_FILE="/var/log/ssl-renew.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] 开始证书续期检查..." >> $LOG_FILE

# 尝试续期所有证书
certbot renew --quiet

if [ $? -eq 0 ]; then
    echo "[$DATE] 证书续期检查完成" >> $LOG_FILE

    # 重新加载 nginx 配置（使新证书生效）
    docker exec nginx-gateway nginx -s reload 2>/dev/null || {
        echo "[$DATE] nginx 重载失败，尝试重启容器..." >> $LOG_FILE
        docker restart nginx-gateway
    }

    echo "[$DATE] nginx 配置已重载" >> $LOG_FILE
else
    echo "[$DATE] 证书续期失败!" >> $LOG_FILE
fi
