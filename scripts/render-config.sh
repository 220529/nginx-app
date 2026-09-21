#!/usr/bin/env bash
# Render the tracked Nginx templates with the shared non-secret deployment
# configuration. Nginx runtime variables such as $host are intentionally
# left untouched.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${DEPLOYMENT_CONFIG_FILE:-$ROOT_DIR/config/deployment.env}"
OUTPUT_DIR="${1:-$ROOT_DIR/.generated/conf.d}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Deployment configuration not found: $CONFIG_FILE" >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
. "$CONFIG_FILE"
set +a

: "${NGINX_DOMAIN:?NGINX_DOMAIN is required}"
: "${NGINX_UPSTREAM_HOST:?NGINX_UPSTREAM_HOST is required}"
: "${NGINX_UPSTREAM_PORT:?NGINX_UPSTREAM_PORT is required}"
: "${NGINX_WEBROOT_PATH:?NGINX_WEBROOT_PATH is required}"

NGINX_CERT_DIR="${NGINX_CERT_DIR:-/etc/letsencrypt/live/$NGINX_DOMAIN}"

case "$NGINX_UPSTREAM_PORT" in
    *[!0-9]*|'')
        echo "NGINX_UPSTREAM_PORT must be numeric." >&2
        exit 1
        ;;
esac

for value_name in NGINX_DOMAIN NGINX_UPSTREAM_HOST NGINX_WEBROOT_PATH NGINX_CERT_DIR; do
    value="${!value_name}"
    case "$value" in
        *$'\n'*|*$'\r'*)
            echo "$value_name must not contain a newline." >&2
            exit 1
            ;;
    esac
done

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}

domain_value="$(escape_sed_replacement "$NGINX_DOMAIN")"
upstream_host_value="$(escape_sed_replacement "$NGINX_UPSTREAM_HOST")"
upstream_port_value="$(escape_sed_replacement "$NGINX_UPSTREAM_PORT")"
webroot_value="$(escape_sed_replacement "$NGINX_WEBROOT_PATH")"
cert_dir_value="$(escape_sed_replacement "$NGINX_CERT_DIR")"

mkdir -p "$OUTPUT_DIR"

render_template() {
    local template_path="$1"
    local output_path="$2"

    if [ ! -f "$template_path" ]; then
        echo "Nginx template not found: $template_path" >&2
        exit 1
    fi

    sed \
        -e "s|__NGINX_DOMAIN__|$domain_value|g" \
        -e "s|__NGINX_UPSTREAM_HOST__|$upstream_host_value|g" \
        -e "s|__NGINX_UPSTREAM_PORT__|$upstream_port_value|g" \
        -e "s|__NGINX_WEBROOT_PATH__|$webroot_value|g" \
        -e "s|__NGINX_CERT_DIR__|$cert_dir_value|g" \
        "$template_path" > "$output_path"
}

render_template \
    "$ROOT_DIR/conf.d/nginx.conf" \
    "$OUTPUT_DIR/nginx.conf"
render_template \
    "$ROOT_DIR/conf.d/nginx-http.conf.example" \
    "$OUTPUT_DIR/nginx-http.conf.example"

echo "Rendered Nginx configurations to $OUTPUT_DIR"
