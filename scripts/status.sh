#!/usr/bin/env bash
# Show the host Nginx status and listening ports.

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
: "${NGINX_UPSTREAM_HOST:?NGINX_UPSTREAM_HOST is required}"
: "${NGINX_UPSTREAM_PORT:?NGINX_UPSTREAM_PORT is required}"
: "${NGINX_HEALTH_PATH:?NGINX_HEALTH_PATH is required}"

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

run_privileged systemctl --no-pager --full status nginx || true
echo
echo "Listening ports:"
ss -ltnp | grep -E ':(80|443)\b' || true
echo
echo "ERP frontend upstream:"
curl --silent --show-error --max-time 10 \
    --header "Host: $NGINX_DOMAIN" \
    --head "http://${NGINX_UPSTREAM_HOST}:${NGINX_UPSTREAM_PORT}${NGINX_HEALTH_PATH}" || true
