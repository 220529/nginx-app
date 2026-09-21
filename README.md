# nginx-app

宿主机 Nginx 共享网关。它只负责域名入口、TLS、反向代理和发布回滚，不负责任何业务项目的镜像构建或容器编排。

## 设计边界

每个业务项目独立部署自己的应用容器，并把需要暴露的前端端口绑定到服务器回环地址；本仓库统一管理宿主机 Nginx：

```text
Internet
   |
   | project-a.example.com / project-b.example.com
   v
宿主机 Nginx
   |-- site-a -> http://127.0.0.1:8080
   |-- site-b -> http://127.0.0.1:8090
   `-- 每个站点独立的 HTTP/HTTPS、证书和健康检查配置
```

论文系统只是当前的一个站点，不是网关的实现前提。应用镜像和数据库仍由各自的应用仓库负责。

## 配置分层

| 路径 | 职责 |
| --- | --- |
| `config/gateway.env` | 网关公共配置：Tag 前缀、暂存目录、配置目录、备份目录、ACME Webroot、统一续期 timer |
| `config/sites/*.env` | 一个文件对应一个项目站点，维护域名、上游、TLS 和健康检查 |
| `config/templates/` | 所有站点共用的 HTTP/HTTPS Nginx 模板 |
| `scripts/lib/gateway-common.sh` | 渲染、部署、状态检查共用的字段默认值和校验规则 |
| `scripts/render-config.sh` | 将站点清单渲染成可上传的发布包 |
| `scripts/deploy-host-nginx.sh` | 服务器端的安装、证书、续期、原子替换、健康检查和回滚入口 |
| `.github/workflows/deploy.yml` | Tag 触发、配置校验、上传和远程执行 |
| `tag.sh` / `scripts/deploy.bat` | 生成并推送网关发布 Tag |
| `scripts/start.sh` / `scripts/restart.sh` | 宿主机 Nginx 启动和安全 reload |
| `scripts/status.sh` / `scripts/logs.sh` | 网关状态、站点健康和日志检查 |

`docker-compose-prod.yml` 和根目录 `nginx.conf` 是旧版 Docker 网关的兼容参考，不是当前宿主机生产入口。

## 新增项目

复制一个站点配置并只修改项目差异：

```bash
cp config/sites/erp-settlement.env config/sites/example.env
```

至少调整以下字段：

```env
SITE_NAME=example
SITE_DOMAIN=example.example.com
SITE_CONFIG_FILE=example.conf
SITE_UPSTREAM_URL=http://127.0.0.1:8090
SITE_TLS_ENABLED=true
SITE_CERTBOT_ENABLED=true
SITE_HEALTH_PATH=/
SITE_API_HEALTH_PATH=
SITE_HEALTH_CHECK_REQUIRED=true
```

然后提交配置并运行 `./tag.sh`。新增项目不需要新增 Nginx 脚本、systemd timer 或 workflow；流水线会把所有 `config/sites/*.env` 作为一个站点清单统一渲染和发布。

删除站点时删除对应的 `config/sites/<name>.env` 后再发布。部署会移除该站点的受管 `*.conf`，但不会自动删除证书，避免误删仍可能被其他流程使用的 TLS 资料。

## 发布与回滚

推送 `master/nginx-app/YYYY-MM-DD/HH-MM-SS` Tag 触发 GitHub Actions：

1. 加载网关公共配置和全部站点配置；
2. 使用共享校验库渲染 HTTPS 生产配置和 HTTP 证书申请配置；
3. 在 Runner 内用 Nginx 容器校验配置语法；
4. 上传一个完整的网关发布包到服务器暂存目录；
5. 首次缺证书的站点临时启用 HTTP ACME 路由并申请证书；
6. 备份当前受管站点，原子替换配置并执行 `nginx -t`；
7. reload Nginx，按各站点配置执行健康检查；
8. 配置校验、reload 或健康检查失败时恢复上一版站点集合。

服务器上的统一路径为：

```text
/tmp/nginx-gateway/                         # 发布暂存目录
/etc/nginx/conf.d/<SITE_CONFIG_FILE>        # 每个站点一份受管配置
/etc/nginx/conf.d/.nginx-gateway-managed    # 受管配置清单
/var/lib/nginx-gateway/previous/            # 发布回滚备份
/var/www/nginx-gateway/acme/                # 所有站点共享 ACME Webroot
/etc/letsencrypt/live/<domain>/             # Certbot 按域名保存证书
nginx-gateway-certbot-renew.timer           # 所有站点共用的续期 timer
```

## 前置条件和凭据

- 服务器已安装并由 systemd 管理 Nginx；
- SSH 用户是 root，或可以免交互执行 `sudo install`、`sudo nginx`、`sudo systemctl`；
- 每个站点的 DNS 已解析到服务器，公网 TCP 80、443 已放行；
- 每个站点的应用先在对应上游地址运行；
- GitHub Actions Secrets 配置 `SSH_HOST`、`SSH_USERNAME`、`SSH_PASSWORD` 和 `CERTBOT_EMAIL`；
- SSH 凭据、证书和其他密钥不提交到 Git。

本仓库只发布 Nginx 网关。应用仓库继续使用自己的 Tag 流程构建镜像、推送 ACR 并更新应用容器。
