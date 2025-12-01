#!/bin/bash
# SSL 证书初始化脚本
# 首次运行时使用，申请 Let's Encrypt 证书

set -e

# 域名列表
DOMAINS=(
    "erp.lytt.fun"
    "lego.lytt.fun"
    "lego.api.lytt.fun"
    "nest.lytt.fun"
)

# 邮箱（用于证书过期提醒）
EMAIL="15713857919@163.com"

# 证书存储目录
CERT_DIR="/etc/letsencrypt"

echo "=========================================="
echo "  Let's Encrypt SSL 证书初始化"
echo "=========================================="

# 检查 certbot 是否安装
if ! command -v certbot &> /dev/null; then
    echo "正在安装 certbot..."
    apt-get update
    apt-get install -y certbot
fi

# 停止 nginx（释放 80 端口给 certbot）
echo "停止 nginx 以释放 80 端口..."
docker compose -f /app/nginx-app/docker-compose-prod.yml down || true

# 为每个域名申请证书
for domain in "${DOMAINS[@]}"; do
    echo ""
    echo "正在为 $domain 申请证书..."

    certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email $EMAIL \
        -d $domain \
        --keep-until-expiring

    if [ $? -eq 0 ]; then
        echo "✅ $domain 证书申请成功"
    else
        echo "❌ $domain 证书申请失败"
    fi
done

# 重启 nginx
echo ""
echo "重启 nginx..."
docker compose -f /app/nginx-app/docker-compose-prod.yml up -d

echo ""
echo "=========================================="
echo "  证书申请完成！"
echo "=========================================="
echo ""
echo "证书位置:"
for domain in "${DOMAINS[@]}"; do
    echo "  $domain:"
    echo "    证书: $CERT_DIR/live/$domain/fullchain.pem"
    echo "    私钥: $CERT_DIR/live/$domain/privkey.pem"
done
