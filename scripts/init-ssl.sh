#!/usr/bin/env bash
# Request a Let's Encrypt certificate for the single active gateway domain.

set -Eeuo pipefail

DOMAIN="${DOMAIN:-erp.lytt.fun}"
: "${CERTBOT_EMAIL:?Set CERTBOT_EMAIL before running this script}"

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

if ! command -v certbot >/dev/null 2>&1; then
    echo "certbot is not installed. Install it with the system package manager first." >&2
    exit 1
fi

nginx_was_active=0
if run_privileged systemctl is-active --quiet nginx; then
    nginx_was_active=1
    run_privileged systemctl stop nginx
fi

restore_nginx() {
    if [ "$nginx_was_active" -eq 1 ]; then
        run_privileged systemctl start nginx
    fi
}
trap restore_nginx EXIT

run_privileged certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$CERTBOT_EMAIL" \
    --domain "$DOMAIN" \
    --keep-until-expiring

echo "Certificate issued for $DOMAIN. Push a master/nginx-app/* Tag to deploy the HTTPS configuration."
