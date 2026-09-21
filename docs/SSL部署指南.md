# SSL/HTTPS 部署指南

生产环境使用宿主机 Nginx 终止 TLS：

```text
HTTP :80  -> 301 -> HTTPS :443
HTTPS      -> 127.0.0.1:8080
```

证书只保存在服务器 `/etc/letsencrypt`，不提交到 Git。

## 1. 准备条件

- `erp.lytt.fun` 的 DNS 已解析到当前服务器；
- 云安全组和系统防火墙允许 TCP 80、443；
- 论文系统已经能够响应 `127.0.0.1:8080`；
- 宿主机 Nginx 已安装并运行。

检查：

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
curl -I http://127.0.0.1:8080/login
```

## 2. 首次申请证书

安装 Certbot：

```bash
sudo apt-get update
sudo apt-get install -y certbot
```

先把仓库中的临时 HTTP 配置放到活动位置：

```bash
cd /app/nginx-app
sudo install -m 0644 \
  conf.d/nginx-http.conf.example \
  /etc/nginx/conf.d/erp-settlement.conf
sudo nginx -t
sudo systemctl reload nginx
```

申请证书：

```bash
CERTBOT_EMAIL=your-email@example.com ./scripts/init-ssl.sh
```

脚本会短暂停止宿主机 Nginx，使用 standalone 模式申请证书，完成后自动恢复 Nginx。

检查证书：

```bash
sudo certbot certificates
sudo test -s /etc/letsencrypt/live/erp.lytt.fun/fullchain.pem
sudo test -s /etc/letsencrypt/live/erp.lytt.fun/privkey.pem
```

## 3. 使用 Tag 发布 HTTPS

证书存在后，在本地推送部署 Tag：

```bash
cd /Users/kaixin/main/nginx-app
./tag.sh
```

Tag 格式为：

```text
master/nginx-app/YYYY-MM-DD/HH-MM-SS
```

GitHub Actions 会在 Runner 中使用临时证书校验 Nginx 配置；服务器端会再次确认真实证书存在，然后备份、替换并 reload Nginx。

## 4. 验证 HTTPS

```bash
curl -I http://erp.lytt.fun/login
curl -I https://erp.lytt.fun/login
curl -fsS https://erp.lytt.fun/api/health
```

HTTP 应返回 301，HTTPS 页面和接口应返回成功状态。

## 5. 自动续期

检查 Certbot timer：

```bash
systemctl list-timers | grep certbot
```

手动执行续期检查：

```bash
sudo /app/nginx-app/scripts/renew-ssl.sh
```

证书成功续期后脚本只 reload Nginx，不重启论文系统。

## 回滚

GitHub Actions 会保留：

```text
/etc/nginx/conf.d/erp-settlement.conf.previous
```

如果 HTTPS 配置出现问题，可先恢复临时 HTTP 配置：

```bash
sudo install -m 0644 \
  /app/nginx-app/conf.d/nginx-http.conf.example \
  /etc/nginx/conf.d/erp-settlement.conf
sudo nginx -t
sudo systemctl reload nginx
```
