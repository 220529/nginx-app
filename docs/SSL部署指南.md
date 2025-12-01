# SSL/HTTPS 部署指南

## 概述

本文档说明如何为 nginx-gateway 配置 Let's Encrypt SSL 证书，实现 HTTPS 访问。

## 涉及域名

| 域名 | 服务 |
|------|------|
| erp.lytt.fun | ERP 系统 |
| lego.lytt.fun | Lego 前端 |
| lego.api.lytt.fun | Lego API |
| nest.lytt.fun | Nest 服务 |

## 文件说明

```
nginx-app/
├── conf.d/
│   ├── nginx.conf       # HTTP 配置（申请证书前使用）
│   └── nginx-ssl.conf   # HTTPS 配置（申请证书后使用）
├── scripts/
│   ├── init-ssl.sh      # 首次申请证书脚本
│   └── renew-ssl.sh     # 证书自动续期脚本
├── certbot/
│   └── www/             # certbot webroot 验证目录
└── docker-compose-prod.yml
```

## 部署步骤

### 步骤 1: 服务器准备

SSH 登录到服务器 (47.93.17.251)：

```bash
ssh root@47.93.17.251
```

### 步骤 2: 安装 certbot

```bash
# Ubuntu/Debian
apt-get update
apt-get install -y certbot

# CentOS/RHEL
yum install -y certbot
```

### 步骤 3: 首次申请证书

**方法一：使用脚本（推荐）**

```bash
cd /app/nginx-app
chmod +x scripts/init-ssl.sh
./scripts/init-ssl.sh
```

**方法二：手动申请**

```bash
# 1. 停止 nginx 释放 80 端口
docker compose -f /app/nginx-app/docker-compose-prod.yml down

# 2. 为每个域名申请证书
certbot certonly --standalone -d erp.lytt.fun
certbot certonly --standalone -d lego.lytt.fun
certbot certonly --standalone -d lego.api.lytt.fun
certbot certonly --standalone -d nest.lytt.fun

# 3. 查看证书
ls -la /etc/letsencrypt/live/
```

### 步骤 4: 切换到 HTTPS 配置

```bash
cd /app/nginx-app/conf.d

# 备份原配置
mv nginx.conf nginx-http-only.conf.bak

# 使用 SSL 配置
mv nginx-ssl.conf nginx.conf
```

### 步骤 5: 创建必要目录

```bash
mkdir -p /app/nginx-app/certbot/www
```

### 步骤 6: 重启 nginx

```bash
cd /app/nginx-app
docker compose -f docker-compose-prod.yml up -d

# 检查状态
docker ps
docker logs nginx-gateway
```

### 步骤 7: 验证 HTTPS

```bash
# 测试 HTTPS
curl -I https://erp.lytt.fun

# 测试 HTTP 重定向
curl -I http://erp.lytt.fun
```

浏览器访问：https://erp.lytt.fun

## 证书自动续期

Let's Encrypt 证书有效期 90 天，需要配置自动续期。

### 配置 cron 定时任务

```bash
# 编辑 crontab
crontab -e

# 添加每天凌晨 2 点执行续期检查
0 2 * * * /app/nginx-app/scripts/renew-ssl.sh >> /var/log/ssl-renew.log 2>&1
```

### 手动测试续期

```bash
# 测试续期（不会真正续期，只是检查）
certbot renew --dry-run

# 强制续期
certbot renew --force-renewal
```

## 故障排查

### 证书申请失败

```bash
# 检查 80 端口是否被占用
netstat -tlnp | grep :80

# 检查防火墙
firewall-cmd --list-ports
ufw status

# 确保域名 DNS 解析正确
nslookup erp.lytt.fun
```

### nginx 启动失败

```bash
# 检查配置语法
docker exec nginx-gateway nginx -t

# 查看详细日志
docker logs nginx-gateway --tail 100

# 检查证书文件是否存在
ls -la /etc/letsencrypt/live/erp.lytt.fun/
```

### 证书过期

```bash
# 查看证书过期时间
certbot certificates

# 强制续期
certbot renew --force-renewal

# 重载 nginx
docker exec nginx-gateway nginx -s reload
```

## 回滚方案

如果 HTTPS 配置有问题，可以快速回滚到 HTTP：

```bash
cd /app/nginx-app/conf.d

# 恢复 HTTP 配置
mv nginx.conf nginx-ssl.conf
mv nginx-http-only.conf.bak nginx.conf

# 重启 nginx
docker restart nginx-gateway
```

## 安全建议

1. **HSTS**: 已在 nginx 配置中启用，浏览器会强制使用 HTTPS
2. **TLS 版本**: 仅允许 TLS 1.2 和 1.3
3. **证书监控**: 建议配置证书过期告警（UptimeRobot 支持）

## 后续优化

- [ ] 配置 OCSP Stapling 提升性能
- [ ] 配置 CDN 加速（阿里云 CDN 支持免费 HTTPS）
- [ ] 申请通配符证书 (*.lytt.fun) 简化管理
