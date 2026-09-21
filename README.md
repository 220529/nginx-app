# nginx-app

宿主机 Nginx 网关配置。

## 当前部署模型

服务器只运行宿主机 Nginx，论文系统由另一个 Docker Compose 项目管理：

```text
erp.lytt.fun:80
    -> host Nginx (redirects to HTTPS)
erp.lytt.fun:443
    -> host Nginx
    -> 127.0.0.1:8080
    -> erp-settlement-prod-frontend
    -> /api/ -> backend:3000
```

宿主机 Nginx 不加入论文系统的 Docker 网络，也不负责启动论文系统容器。

## 文件约定

| 路径 | 用途 |
| --- | --- |
| `config/deployment.env` | 域名、上游、路径、健康检查等非敏感配置 |
| `conf.d/nginx.conf` | 生产 HTTPS 配置模板 |
| `conf.d/nginx-http.conf.example` | 申请证书前的 HTTP 配置模板 |
| `scripts/render-config.sh` | 根据共享配置渲染 Nginx 配置 |
| `scripts/deploy-host-nginx.sh` | 服务器端安装、证书、续期和回滚流程 |
| `.github/workflows/deploy.yml` | 校验并发布宿主机 Nginx 配置 |
| `tag.sh` | 生成并推送部署 Tag |
| `scripts/start.sh` | 启动并校验宿主机 Nginx |
| `scripts/restart.sh` | 校验后平滑 reload |
| `scripts/status.sh` | 查看服务和端口状态 |
| `scripts/logs.sh` | 查看 Nginx 日志 |

`docker-compose-prod.yml` 和根目录 `nginx.conf` 仅保留作旧版 Docker 网关兼容参考，当前服务器部署不使用它们。

修改域名、前端端口、部署暂存目录、证书 Webroot、健康检查路径或续期 timer 时，只修改
`config/deployment.env`。不要把 SSH 密码、Certbot 邮箱以外的凭据或证书提交到仓库。

## 发布

GitHub Actions 由 `master/nginx-app/**` Tag 触发。推荐直接运行：

```bash
./tag.sh
```

生成的 Tag 示例：

```text
master/nginx-app/2026-09-21/15-17-34
```

注意：本仓库的流水线只发布宿主机 Nginx，不构建或推送论文系统前后端镜像；论文系统镜像由
`erp-settlement-thesis` 仓库自己的 Tag 流程负责。

流水线会依次执行：

1. 读取 `config/deployment.env` 并渲染两份配置；
2. 在 Runner 中校验渲染后的 HTTPS 和 HTTP 配置；
3. 上传配置到服务器临时目录；
4. 首次发布时自动安装 Certbot、申请证书并创建续期 timer；
5. 备份当前配置，原子替换配置并执行 `nginx -t`；
6. reload Nginx 并检查 HTTPS 前端/API；
7. 配置或健康检查失败时自动恢复上一版。

## 服务器前置条件

- Nginx 已安装并由 systemd 管理；
- SSH 用户是 root，或具备免交互执行 `sudo install`、`sudo nginx`、`sudo systemctl` 的权限；
- 论文系统前端监听 `127.0.0.1:8080`；
- `erp.lytt.fun` 的 DNS 已解析到该服务器，且公网 TCP 80、443 已放行；
- GitHub Actions Secrets 已添加 `SSH_HOST`、`SSH_USERNAME`、`SSH_PASSWORD` 和 `CERTBOT_EMAIL`。

首次推送 Tag 时，流水线会自动安装 Certbot、申请证书、发布 HTTPS 配置，并创建每日续期 timer。证书文件不进入 Git。
