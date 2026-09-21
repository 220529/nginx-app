#!/usr/bin/env bash
# Renew certificates and reload host Nginx when a certificate changes.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${DEPLOYMENT_CONFIG_FILE:-$ROOT_DIR/config/deployment.env}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "部署配置不存在: $CONFIG_FILE" >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
. "$CONFIG_FILE"
set +a

: "${NGINX_DOMAIN:?NGINX_DOMAIN is required}"

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

run_privileged certbot renew --quiet --deploy-hook "systemctl reload nginx"
