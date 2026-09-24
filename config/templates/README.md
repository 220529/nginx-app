# Nginx templates

模板由所有站点共享，使用以下占位符：

- `__SITE_DOMAIN__`
- `__SITE_UPSTREAM_URL__`
- `__SITE_CERT_DIR__`
- `__GATEWAY_WEBROOT_PATH__`
- `__SITE_EXTRA_LOCATIONS__`

不要在模板中写入具体项目名、域名、端口或证书目录。项目差异全部放在 `config/sites/*.env` 或对应的 `*.locations.conf`；只有代理协议、请求头、ACME 路由等公共行为才应修改模板。
