#!/usr/bin/env bash
# Manual fallback for requesting the first certificate with the webroot method.
# The normal path is the HTTPS deployment workflow, which installs the
# bootstrap configuration before invoking Certbot.

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

DOMAIN="${DOMAIN:-$NGINX_DOMAIN}"
WEBROOT_DIR="${WEBROOT_DIR:-$NGINX_WEBROOT_PATH}"
: "${CERTBOT_EMAIL:?Set CERTBOT_EMAIL before running this script}"

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

if ! command -v certbot >/dev/null 2>&1; then
    echo "certbot is not installed. The Tag deployment workflow installs it automatically." >&2
    exit 1
fi

run_privileged mkdir -p "$WEBROOT_DIR"
run_privileged certbot certonly \
    --webroot \
    --webroot-path "$WEBROOT_DIR" \
    --non-interactive \
    --agree-tos \
    --email "$CERTBOT_EMAIL" \
    --domain "$DOMAIN" \
    --keep-until-expiring

: "${NGINX_TAG_PREFIX:?NGINX_TAG_PREFIX is required}"
echo "Certificate issued for $DOMAIN. Push a ${NGINX_TAG_PREFIX}/* Tag to deploy the HTTPS configuration."
