#!/usr/bin/env bash
# Render every managed site from config/sites/*.env into a gateway staging
# tree. Nginx runtime variables such as $host are intentionally untouched.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATEWAY_CONFIG_FILE="${GATEWAY_CONFIG_FILE:-$ROOT_DIR/config/gateway.env}"
OUTPUT_DIR="${1:-$ROOT_DIR/.generated/gateway}"

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/lib/gateway-common.sh"

if [ ! -f "$GATEWAY_CONFIG_FILE" ]; then
    echo "Gateway configuration not found: $GATEWAY_CONFIG_FILE" >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
. "$GATEWAY_CONFIG_FILE"
set +a

: "${GATEWAY_WEBROOT_PATH:?GATEWAY_WEBROOT_PATH is required}"

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}

load_site() {
    local site_env="$1"
    load_site_config "$site_env"
}

shopt -s nullglob
SITE_ENV_FILES=("$ROOT_DIR"/config/sites/*.env)
if [ "${#SITE_ENV_FILES[@]}" -eq 0 ]; then
    echo "No site definitions found under $ROOT_DIR/config/sites." >&2
    exit 1
fi

validate_gateway_settings

site_names=""
config_names=""
domains=""
for site_env in "${SITE_ENV_FILES[@]}"; do
    load_site "$site_env"

    case " $site_names " in
        *" $SITE_NAME "*)
            echo "Duplicate SITE_NAME: $SITE_NAME" >&2
            exit 1
            ;;
    esac
    case " $config_names " in
        *" $SITE_CONFIG_FILE "*)
            echo "Duplicate SITE_CONFIG_FILE: $SITE_CONFIG_FILE" >&2
            exit 1
            ;;
    esac
    case " $domains " in
        *" $SITE_DOMAIN "*)
            echo "Duplicate SITE_DOMAIN: $SITE_DOMAIN" >&2
            exit 1
            ;;
    esac

    site_names="$site_names $SITE_NAME"
    config_names="$config_names $SITE_CONFIG_FILE"
    domains="$domains $SITE_DOMAIN"
done

rm -f "$OUTPUT_DIR/sites"/*.conf "$OUTPUT_DIR/sites"/*.env "$OUTPUT_DIR/bootstrap"/*.conf 2>/dev/null || true
mkdir -p "$OUTPUT_DIR/sites" "$OUTPUT_DIR/bootstrap"

render_template() {
    local template_path="$1"
    local output_path="$2"
    local domain_value
    local upstream_value
    local cert_dir_value
    local webroot_value

    if [ ! -f "$template_path" ]; then
        echo "Nginx template not found: $template_path" >&2
        exit 1
    fi

    domain_value="$(escape_sed_replacement "$SITE_DOMAIN")"
    upstream_value="$(escape_sed_replacement "$SITE_UPSTREAM_URL")"
    cert_dir_value="$(escape_sed_replacement "$SITE_CERT_DIR")"
    webroot_value="$(escape_sed_replacement "$GATEWAY_WEBROOT_PATH")"

    sed \
        -e "s|__SITE_DOMAIN__|$domain_value|g" \
        -e "s|__SITE_UPSTREAM_URL__|$upstream_value|g" \
        -e "s|__SITE_CERT_DIR__|$cert_dir_value|g" \
        -e "s|__GATEWAY_WEBROOT_PATH__|$webroot_value|g" \
        "$template_path" > "$output_path"
}

for site_env in "${SITE_ENV_FILES[@]}"; do
    load_site "$site_env"

    if [ "$SITE_TLS_ENABLED" = "true" ]; then
        production_template="$ROOT_DIR/config/templates/site-https.conf.template"
    else
        production_template="$ROOT_DIR/config/templates/site-http.conf.template"
    fi

    render_template \
        "$production_template" \
        "$OUTPUT_DIR/sites/$SITE_CONFIG_FILE"
    render_template \
        "$ROOT_DIR/config/templates/site-http.conf.template" \
        "$OUTPUT_DIR/bootstrap/$SITE_CONFIG_FILE"
    cp "$site_env" "$OUTPUT_DIR/sites/$SITE_NAME.env"
done

echo "Rendered ${#SITE_ENV_FILES[@]} gateway site(s) to $OUTPUT_DIR"
