# Site registry

`*.env` 文件是网关的站点清单，每个文件只描述一个反向代理站点。文件名只用于管理和定位，真正安装的 Nginx 文件名由 `SITE_CONFIG_FILE` 决定。

## Required fields

```env
SITE_NAME=example
SITE_DOMAIN=example.example.com
SITE_UPSTREAM_URL=http://127.0.0.1:8090
```

## Optional fields

```env
SITE_CONFIG_FILE=example.conf
SITE_TLS_ENABLED=true
SITE_CERTBOT_ENABLED=true
SITE_CERT_DIR=/etc/letsencrypt/live/example.example.com
SITE_HEALTH_PATH=/
SITE_API_HEALTH_PATH=/api/health
SITE_HEALTH_CHECK_REQUIRED=true
```

`SITE_TLS_ENABLED=false` 时使用 HTTP 生产配置；启用 TLS 时，证书由 Certbot 保存在 `SITE_CERT_DIR`。健康检查路径为空则跳过该项。配置值必须是简单的环境变量赋值，不要在站点文件中放密码、Token 或 Shell 命令。

新增或删除站点后统一通过网关 Tag 发布，禁止直接在服务器手工编辑受管的 `*.conf`。
