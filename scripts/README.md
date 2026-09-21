# Nginx 运维脚本

这些脚本只管理服务器宿主机上的共享 Nginx 网关，不启动任何业务项目容器。业务项目由自己的仓库和 Compose/容器发布流程管理。

## 常用命令

```bash
cd /app/nginx-app

./scripts/status.sh
./scripts/logs.sh error 100
./scripts/logs.sh access 100
./scripts/restart.sh
```

`restart.sh` 会先执行 `nginx -t`，再平滑 reload。`status.sh` 会读取全部 `config/sites/*.env`，展示受管站点和已配置的健康检查。

## 首次申请证书

正常流程只需要在 GitHub 仓库配置 `CERTBOT_EMAIL`，然后运行 `./tag.sh`。流水线会对所有缺证书且启用 Certbot 的站点自动安装 Certbot、临时启用 ACME HTTP 路由、申请证书并配置统一续期 timer。

流水线不可用时，可以手动申请某一个站点的证书。先确保该站点的 HTTP 配置已发布、80 端口可访问，并安装 Certbot：

```bash
sudo apt-get update
sudo apt-get install -y certbot
```

然后传入站点配置文件：

```bash
CERTBOT_EMAIL=your-email@example.com \
  ./scripts/init-ssl.sh config/sites/erp-settlement.env
```

证书生成后运行 `./tag.sh` 发布该站点的 HTTPS 配置。

## 续期和手动校验

```bash
sudo ./scripts/renew-ssl.sh
sudo nginx -t
sudo systemctl status nginx --no-pager
sudo systemctl status nginx-gateway-certbot-renew.timer --no-pager
sudo ss -ltnp | grep -E ':(80|443)\\b'
```

网关只维护一个统一的 `nginx-gateway-certbot-renew.timer`，它会续期服务器上由 Certbot 管理的全部证书。不要为每个项目再创建一套 timer。
