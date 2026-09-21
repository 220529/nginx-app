# SSL/HTTPS 部署指南

生产环境由宿主机 Nginx 终止 TLS。每个启用 TLS 的站点都采用同一套流程：HTTP 只保留 ACME challenge 并跳转 HTTPS，HTTPS 反向代理到该站点的 `SITE_UPSTREAM_URL`。

证书只保存在服务器 `/etc/letsencrypt`，不提交到 Git。

## 一次性前置条件

- 每个 `SITE_DOMAIN` 的 DNS 已解析到当前服务器；
- 云安全组和系统防火墙允许 TCP 80、443；
- 对应应用已经监听站点配置中的 `SITE_UPSTREAM_URL`；
- 宿主机 Nginx 已安装并由 systemd 管理；
- GitHub Secrets 已添加 `SSH_HOST`、`SSH_USERNAME`、`SSH_PASSWORD` 和 `CERTBOT_EMAIL`。

网关公共参数在 `config/gateway.env`，项目差异在 `config/sites/*.env`。当前论文站点配置只是：

```text
config/sites/erp-settlement.env
```

## 自动申请并发布

从网关仓库运行：

```bash
cd /Users/kaixin/main/nginx-app
./tag.sh
```

Tag 格式为：

```text
master/nginx-app/YYYY-MM-DD/HH-MM-SS
```

首次发布某个缺证书的站点时，GitHub Actions 会：

1. 加载全部站点配置并渲染生产配置和 ACME bootstrap 配置；
2. 在 Runner 内用 Nginx 校验配置语法；
3. 上传完整发布包；
4. 自动安装 Certbot（支持 apt、dnf、yum）；
5. 临时启用该站点的 HTTP challenge 并申请证书；
6. 安装所有站点的最终配置并 reload Nginx；
7. 按站点配置检查页面和 API 健康路径。

后续发布不会重复申请仍有效的证书。应用镜像构建和 ACR 发布仍由应用仓库负责。

## 新增站点

```bash
cp config/sites/erp-settlement.env config/sites/example.env
# 编辑 example.env 中的 SITE_* 字段
./tag.sh
```

需要先完成 DNS 和应用上游准备。新增站点不需要新增证书 timer 或 workflow。

## 验证和续期

```bash
curl -I http://example.example.com/
curl -I https://example.example.com/
sudo systemctl status nginx-gateway-certbot-renew.timer --no-pager
sudo systemctl list-timers | grep nginx-gateway-certbot-renew
sudo /usr/local/sbin/nginx-gateway-certbot-renew
```

HTTP 应返回 301；HTTPS 页面和配置的健康接口应返回成功状态。统一 timer 会续期服务器上全部 Certbot 证书，续期成功后只 reload Nginx。

## 回滚

发布会把当前受管配置备份到：

```text
/var/lib/nginx-gateway/previous/
```

同时记录：

```text
/var/lib/nginx-gateway/previous/manifest
/var/lib/nginx-gateway/previous/files.list
```

如果配置校验、reload 或健康检查失败，流水线会自动恢复上一版站点集合。人工操作前先查看 manifest，再执行：

```bash
sudo nginx -t
sudo systemctl reload nginx
```
