# Nginx 运维脚本

这些脚本只管理服务器宿主机上的 Nginx，不负责启动论文系统容器。论文系统由 `/app/erp-settlement-thesis/docker-compose.prod.yml` 管理。

## 常用命令

```bash
cd /app/nginx-app

./scripts/status.sh
./scripts/logs.sh error 100
./scripts/logs.sh access 100
./scripts/restart.sh
```

`restart.sh` 会先执行 `nginx -t`，然后平滑 reload，避免直接停止服务。

## 证书

首次申请证书前安装 Certbot：

```bash
sudo apt-get update
sudo apt-get install -y certbot
```

首次申请 `erp.lytt.fun` 前，先把 `conf.d/nginx-http.conf.example` 安装到 `/etc/nginx/conf.d/erp-settlement.conf`，确认 80 端口可用，再执行：

```bash
sudo install -m 0644 \
  /app/nginx-app/conf.d/nginx-http.conf.example \
  /etc/nginx/conf.d/erp-settlement.conf
sudo nginx -t
sudo systemctl reload nginx
CERTBOT_EMAIL=your-email@example.com ./scripts/init-ssl.sh
```

证书生成后运行 `/app/nginx-app/tag.sh` 发布 HTTPS 配置。

续期检查：

```bash
sudo ./scripts/renew-ssl.sh
```

## 手动校验

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
sudo ss -ltnp | grep -E ':(80|443)\b'
curl -I -H 'Host: erp.lytt.fun' http://127.0.0.1/login
```
