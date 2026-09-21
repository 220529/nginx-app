# SSL/HTTPS 部署指南

生产环境使用宿主机 Nginx 终止 TLS：

```text
HTTP :80  -> 301 -> HTTPS :443
HTTPS      -> 127.0.0.1:8080
```

证书只保存在服务器 `/etc/letsencrypt`，不提交到 Git。

## 1. 一次性前置条件

- `erp.lytt.fun` 的 DNS 已解析到当前服务器；
- 云安全组和系统防火墙允许 TCP 80、443；
- 论文系统已经能够响应 `127.0.0.1:8080`；
- 宿主机 Nginx 已安装并由 systemd 管理；
- GitHub 仓库 Secrets 中已添加 `SSH_HOST`、`SSH_USERNAME`、`SSH_PASSWORD` 和 `CERTBOT_EMAIL`。

域名、上游端口、部署暂存目录、Webroot、健康检查路径和 timer 参数统一维护在：

```text
config/deployment.env
```

## 2. 自动申请并发布

本仓库的 Tag 只负责宿主机 Nginx 和证书，不负责论文系统前后端镜像构建；应用镜像由
`erp-settlement-thesis` 仓库的发布流程负责。

直接在本地运行：

```bash
cd /Users/kaixin/main/nginx-app
./tag.sh
```

生成的 Tag 格式为：

```text
master/nginx-app/YYYY-MM-DD/HH-MM-SS
```

首次 Tag 发布时，GitHub Actions 会自动：

1. 读取共享配置并渲染 HTTPS 和临时 HTTP 配置；
2. 校验渲染后的配置；
3. 上传生产配置和证书申请用的 bootstrap 配置；
4. 在服务器安装 Certbot（支持 apt、dnf、yum）；
5. 临时启用 HTTP challenge 路由并申请证书；
6. 切换到 HTTPS 配置；
7. 创建每日证书续期 timer；
8. 检查 HTTPS 页面和 API 健康接口。

后续 Tag 不会重复申请证书，只会发布新配置。

## 3. 验证

```bash
curl -I http://erp.lytt.fun/login
curl -I https://erp.lytt.fun/login
curl -fsS https://erp.lytt.fun/api/health
```

HTTP 应返回 301，HTTPS 页面和接口应返回成功状态。

服务器上检查续期 timer：

```bash
systemctl status erp-settlement-certbot-renew.timer --no-pager
systemctl list-timers | grep erp-settlement-certbot
```

## 4. 手动续期检查

自动 timer 执行的脚本是：

```bash
sudo /usr/local/sbin/erp-settlement-certbot-renew
```

证书成功续期后会 reload Nginx，不会重启论文系统。

## 5. 回滚

GitHub Actions 会保留：

```text
/etc/nginx/conf.d/erp-settlement.conf.previous
```

如果 HTTPS 配置校验失败，流水线自动恢复上一版。需要人工恢复时：

```bash
sudo install -m 0644 \
  /etc/nginx/conf.d/erp-settlement.conf.previous \
  /etc/nginx/conf.d/erp-settlement.conf
sudo nginx -t
sudo systemctl reload nginx
```
