#!/usr/bin/env bash
# Show gateway service state and the health of configured sites.

set -Eeuo pipefail
shopt -s nullglob

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

SITE_ENV_FILES=("$ROOT_DIR"/config/sites/*.env)
if [ "${#SITE_ENV_FILES[@]}" -eq 0 ]; then
    echo "No site definitions found under $ROOT_DIR/config/sites." >&2
    exit 1
fi

run_privileged systemctl --no-pager --full status nginx || true
echo
echo "Listening ports:"
ss -ltnp | grep -E ':(80|443)\b' || true
echo
echo "Configured sites:"
has_certbot_site=0

for site_env in "${SITE_ENV_FILES[@]}"; do
    load_site_config "$site_env"
    protocol=http
    curl_extra=(--resolve "${SITE_DOMAIN}:80:127.0.0.1")
    if [ "$SITE_TLS_ENABLED" = "true" ]; then
        has_tls_site=1
        protocol=https
        curl_extra=(--insecure --resolve "${SITE_DOMAIN}:443:127.0.0.1")
    fi
    printf -- '- %s: %s -> %s (%s)\n' "$SITE_NAME" "$SITE_DOMAIN" "$SITE_UPSTREAM_URL" "$protocol"
    if [ "$SITE_TLS_ENABLED" = "true" ] && [ "$SITE_CERTBOT_ENABLED" = "true" ]; then
        has_certbot_site=1
    fi

    if [ "$SITE_HEALTH_CHECK_REQUIRED" = "true" ]; then
        for health_path in "$SITE_HEALTH_PATH" "$SITE_API_HEALTH_PATH"; do
            [ -n "$health_path" ] || continue
            if curl --fail --silent --show-error --max-time 15 "${curl_extra[@]}" \
                "${protocol}://${SITE_DOMAIN}${health_path}" >/dev/null; then
                printf '  health %s: ok\n' "$health_path"
            else
                printf '  health %s: failed\n' "$health_path"
            fi
        done
    fi
done

if [ -f "$GATEWAY_MANIFEST_PATH" ]; then
    echo
    echo "Managed config manifest: $GATEWAY_MANIFEST_PATH"
    cat "$GATEWAY_MANIFEST_PATH"
fi

if [ "$has_certbot_site" -eq 1 ]; then
    echo
    run_privileged systemctl --no-pager --full status "${GATEWAY_CERTBOT_TIMER_NAME}.timer" || true
fi
