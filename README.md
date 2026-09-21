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
| `conf.d/nginx.conf` | 当前生产 HTTPS 配置 |
| `conf.d/nginx-http.conf.example` | 申请证书前的临时 HTTP 配置 |
| `.github/workflows/deploy.yml` | 校验并发布宿主机 Nginx 配置 |
| `tag.sh` | 生成并推送部署 Tag |
| `scripts/start.sh` | 启动并校验宿主机 Nginx |
| `scripts/restart.sh` | 校验后平滑 reload |
| `scripts/status.sh` | 查看服务和端口状态 |
| `scripts/logs.sh` | 查看 Nginx 日志 |

`docker-compose-prod.yml` 和根目录 `nginx.conf` 仅保留作旧版 Docker 网关兼容参考，当前服务器部署不使用它们。

## 发布

GitHub Actions 由 `master/nginx-app/**` Tag 触发。推荐直接运行：

```bash
./tag.sh
```

生成的 Tag 示例：

```text
master/nginx-app/2026-09-21/15-17-34
```

流水线会依次执行：

1. 在 Runner 中校验 Nginx 配置；
2. 上传配置到服务器临时目录；
3. 备份当前配置；
4. 原子替换配置并执行 `nginx -t`；
5. reload Nginx；
6. 配置失败时自动恢复上一版。

## 服务器前置条件

- Nginx 已安装并由 systemd 管理；
- SSH 用户是 root，或具备免交互执行 `sudo install`、`sudo nginx`、`sudo systemctl` 的权限；
- 论文系统前端监听 `127.0.0.1:8080`；
- `erp.lytt.fun` 的 DNS 已解析到该服务器；
- `/etc/letsencrypt/live/erp.lytt.fun/fullchain.pem` 和 `privkey.pem` 已存在。

证书只需在服务器上初始化一次，之后由 Tag 发布 HTTPS 配置。证书文件不进入 Git。
