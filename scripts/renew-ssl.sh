#!/usr/bin/env bash
# Renew all Certbot-managed certificates and reload host Nginx when changed.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATEWAY_CONFIG_FILE="${GATEWAY_CONFIG_FILE:-$ROOT_DIR/config/gateway.env}"
if [ ! -f "$GATEWAY_CONFIG_FILE" ]; then
    echo "Gateway configuration not found: $GATEWAY_CONFIG_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/lib/gateway-common.sh"
set -a
# shellcheck disable=SC1090
. "$GATEWAY_CONFIG_FILE"
set +a
validate_gateway_settings

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

if ! command -v certbot >/dev/null 2>&1; then
    echo "certbot is not installed on this host." >&2
    exit 1
fi

run_privileged certbot renew --quiet --deploy-hook "systemctl reload nginx"
