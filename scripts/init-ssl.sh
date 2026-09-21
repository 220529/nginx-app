#!/usr/bin/env bash
# Manual fallback for requesting one site's first certificate.
# Usage: CERTBOT_EMAIL=... ./scripts/init-ssl.sh config/sites/example.env

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATEWAY_CONFIG_FILE="${GATEWAY_CONFIG_FILE:-$ROOT_DIR/config/gateway.env}"
SITE_ENV_FILE="${SITE_ENV_FILE:-${1:-}}"

if [ ! -f "$GATEWAY_CONFIG_FILE" ]; then
    echo "Gateway configuration not found: $GATEWAY_CONFIG_FILE" >&2
    exit 1
fi
if [ -z "$SITE_ENV_FILE" ] || [ ! -f "$SITE_ENV_FILE" ]; then
    echo "Pass one site definition, for example: $ROOT_DIR/config/sites/example.env" >&2
    exit 1
fi

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/lib/gateway-common.sh"
set -a
# shellcheck disable=SC1090
. "$GATEWAY_CONFIG_FILE"
set +a
validate_gateway_settings
load_site_config "$SITE_ENV_FILE"
: "${GATEWAY_TAG_PREFIX:?GATEWAY_TAG_PREFIX is required}"

[ "$SITE_TLS_ENABLED" = "true" ] || {
    echo "TLS is disabled for $SITE_NAME; no certificate is needed." >&2
    exit 1
}
[ "$SITE_CERTBOT_ENABLED" = "true" ] || {
    echo "Certbot is disabled for $SITE_NAME." >&2
    exit 1
}
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

run_privileged mkdir -p "$GATEWAY_WEBROOT_PATH"
run_privileged certbot certonly \
    --webroot \
    --webroot-path "$GATEWAY_WEBROOT_PATH" \
    --non-interactive \
    --agree-tos \
    --email "$CERTBOT_EMAIL" \
    --domain "$SITE_DOMAIN" \
    --keep-until-expiring

echo "Certificate issued for $SITE_DOMAIN. Push a ${GATEWAY_TAG_PREFIX}/* Tag to deploy the site configuration."
