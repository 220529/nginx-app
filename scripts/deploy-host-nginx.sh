#!/usr/bin/env bash
# Deploy every site described by the staged config/sites/*.env files.

set -Eeuo pipefail
shopt -s nullglob

: "${GATEWAY_STAGING_DIR:?GATEWAY_STAGING_DIR is required}"
: "${GATEWAY_CONFIG_DIR:?GATEWAY_CONFIG_DIR is required}"
: "${GATEWAY_MANIFEST_PATH:?GATEWAY_MANIFEST_PATH is required}"
: "${GATEWAY_BACKUP_DIR:?GATEWAY_BACKUP_DIR is required}"
: "${GATEWAY_WEBROOT_PATH:?GATEWAY_WEBROOT_PATH is required}"
: "${GATEWAY_CERTBOT_TIMER_NAME:?GATEWAY_CERTBOT_TIMER_NAME is required}"
: "${GATEWAY_RENEW_ON_CALENDAR:?GATEWAY_RENEW_ON_CALENDAR is required}"
: "${GATEWAY_RENEW_RANDOM_DELAY:?GATEWAY_RENEW_RANDOM_DELAY is required}"
: "${GATEWAY_DEPLOY_SCRIPT_PATH:?GATEWAY_DEPLOY_SCRIPT_PATH is required}"

GATEWAY_COMMON_FILE="${GATEWAY_COMMON_FILE:-$GATEWAY_STAGING_DIR/lib/gateway-common.sh}"
if [ ! -f "$GATEWAY_COMMON_FILE" ]; then
    echo "Shared gateway library not found: $GATEWAY_COMMON_FILE" >&2
    exit 1
fi
# shellcheck disable=SC1090
. "$GATEWAY_COMMON_FILE"
validate_gateway_settings

STAGED_SITES_DIR="$GATEWAY_STAGING_DIR/sites"
STAGED_BOOTSTRAP_DIR="$GATEWAY_STAGING_DIR/bootstrap"
BACKUP_MANIFEST_PATH="$GATEWAY_BACKUP_DIR/manifest"
BACKUP_FILES_LIST="$GATEWAY_BACKUP_DIR/files.list"

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

NGINX_BIN="$(command -v nginx || true)"
SYSTEMCTL_BIN="$(command -v systemctl || true)"
if [ -z "$NGINX_BIN" ] && [ -x /usr/sbin/nginx ]; then
    NGINX_BIN=/usr/sbin/nginx
fi
if [ -z "$NGINX_BIN" ] || [ -z "$SYSTEMCTL_BIN" ]; then
    echo "Both nginx and systemctl are required on the server." >&2
    exit 1
fi

load_site() {
    local site_env="$1"
    load_site_config "$site_env"
}

SITE_ENV_FILES=("$STAGED_SITES_DIR"/*.env)
if [ "${#SITE_ENV_FILES[@]}" -eq 0 ]; then
    echo "No staged site definitions found: $STAGED_SITES_DIR/*.env" >&2
    exit 1
fi

DESIRED_CONFIG_NAMES=()
MISSING_CERT_SITE_ENV_FILES=()
site_names=""
config_names=""
domains=""
has_certbot_site=0

for site_env in "${SITE_ENV_FILES[@]}"; do
    load_site "$site_env"
    case " $site_names " in *" $SITE_NAME "*) echo "Duplicate SITE_NAME: $SITE_NAME" >&2; exit 1 ;; esac
    case " $config_names " in *" $SITE_CONFIG_FILE "*) echo "Duplicate SITE_CONFIG_FILE: $SITE_CONFIG_FILE" >&2; exit 1 ;; esac
    case " $domains " in *" $SITE_DOMAIN "*) echo "Duplicate SITE_DOMAIN: $SITE_DOMAIN" >&2; exit 1 ;; esac
    DESIRED_CONFIG_NAMES+=("$SITE_CONFIG_FILE")
    site_names="$site_names $SITE_NAME"
    config_names="$config_names $SITE_CONFIG_FILE"
    domains="$domains $SITE_DOMAIN"

    if [ "$SITE_TLS_ENABLED" = "true" ]; then
        if [ "$SITE_CERTBOT_ENABLED" = "true" ]; then
            has_certbot_site=1
        fi
        cert_missing=0
        for certificate in "$SITE_CERT_DIR/fullchain.pem" "$SITE_CERT_DIR/privkey.pem"; do
            [ -s "$certificate" ] || cert_missing=1
        done
        if [ "$cert_missing" -eq 1 ]; then
            [ "$SITE_CERTBOT_ENABLED" = "true" ] || {
                echo "TLS certificate is missing and Certbot is disabled: $site_env" >&2
                exit 1
            }
            MISSING_CERT_SITE_ENV_FILES+=("$site_env")
        fi
    fi
done

PREVIOUS_CONFIG_NAMES=()
if [ -f "$GATEWAY_MANIFEST_PATH" ]; then
    while IFS= read -r config_name; do
        [ -n "$config_name" ] || continue
        validate_config_filename "$config_name"
        PREVIOUS_CONFIG_NAMES+=("$config_name")
    done < "$GATEWAY_MANIFEST_PATH"
fi

backup_path_for() { printf '%s/%s' "$GATEWAY_BACKUP_DIR" "$1"; }
backup_names=""
backup_existing_file() {
    local config_name="$1"
    case " $backup_names " in *" $config_name "*) return 0 ;; esac
    backup_names="$backup_names $config_name"
    if [ -f "$GATEWAY_CONFIG_DIR/$config_name" ]; then
        run_privileged cp -p "$GATEWAY_CONFIG_DIR/$config_name" "$(backup_path_for "$config_name")"
        printf '%s\n' "$config_name" | run_privileged tee -a "$BACKUP_FILES_LIST" >/dev/null
    else
        run_privileged rm -f "$(backup_path_for "$config_name")"
    fi
}

run_privileged mkdir -p "$GATEWAY_CONFIG_DIR" "$GATEWAY_BACKUP_DIR" "$GATEWAY_WEBROOT_PATH"
run_privileged rm -f "$BACKUP_FILES_LIST"
if [ -f "$GATEWAY_MANIFEST_PATH" ]; then
    run_privileged cp -p "$GATEWAY_MANIFEST_PATH" "$BACKUP_MANIFEST_PATH"
else
    run_privileged rm -f "$BACKUP_MANIFEST_PATH"
fi
for config_name in "${PREVIOUS_CONFIG_NAMES[@]}" "${DESIRED_CONFIG_NAMES[@]}"; do
    [ -n "$config_name" ] && backup_existing_file "$config_name"
done

cleanup() {
    rm -f "$GATEWAY_DEPLOY_SCRIPT_PATH" "$GATEWAY_COMMON_FILE" "$STAGED_SITES_DIR"/*.conf \
        "$STAGED_SITES_DIR"/*.env "$STAGED_BOOTSTRAP_DIR"/*.conf
    run_privileged rm -f "$GATEWAY_CONFIG_DIR"/*.next "${GATEWAY_MANIFEST_PATH}.next"
}
trap cleanup EXIT

rollback() {
    echo "Restoring the previous managed Nginx site set..."
    for config_name in "${PREVIOUS_CONFIG_NAMES[@]}" "${DESIRED_CONFIG_NAMES[@]}"; do
        [ -n "$config_name" ] && run_privileged rm -f "$GATEWAY_CONFIG_DIR/$config_name"
    done
    if [ -f "$BACKUP_FILES_LIST" ]; then
        while IFS= read -r config_name; do
            [ -n "$config_name" ] || continue
            run_privileged install -m 0644 "$(backup_path_for "$config_name")" "$GATEWAY_CONFIG_DIR/$config_name"
        done < "$BACKUP_FILES_LIST"
    fi
    if [ -f "$BACKUP_MANIFEST_PATH" ]; then
        run_privileged install -m 0644 "$BACKUP_MANIFEST_PATH" "$GATEWAY_MANIFEST_PATH"
    else
        run_privileged rm -f "$GATEWAY_MANIFEST_PATH"
    fi
    run_privileged "$NGINX_BIN" -t || true
    run_privileged "$SYSTEMCTL_BIN" reload-or-restart nginx || true
}

install_staged_config() {
    local source_path="$1"
    local config_name="$2"
    local active_path="$GATEWAY_CONFIG_DIR/$config_name"
    if [ ! -f "$source_path" ]; then
        echo "Staged site configuration not found: $source_path" >&2
        return 1
    fi
    run_privileged install -m 0644 "$source_path" "${active_path}.next"
    run_privileged mv "${active_path}.next" "$active_path"
}

validate_and_reload() {
    run_privileged "$NGINX_BIN" -t || { rollback; return 1; }
    run_privileged "$SYSTEMCTL_BIN" reload-or-restart nginx || { rollback; return 1; }
}

install_certbot() {
    local certbot_bin="$(command -v certbot || true)"
    if [ -n "$certbot_bin" ]; then CERTBOT_BIN="$certbot_bin"; return 0; fi
    echo "Certbot is missing; installing it with the available package manager..."
    if command -v apt-get >/dev/null 2>&1; then
        run_privileged apt-get update && run_privileged apt-get install -y certbot
    elif command -v dnf >/dev/null 2>&1; then
        run_privileged dnf install -y certbot
    elif command -v yum >/dev/null 2>&1; then
        run_privileged yum install -y certbot
    else
        echo "No supported package manager was found for Certbot." >&2
        return 1
    fi
    CERTBOT_BIN="$(command -v certbot || true)"
    [ -n "$CERTBOT_BIN" ] || { echo "Certbot executable was not found after installation." >&2; return 1; }
}

configure_renewal_timer() {
    local renew_script="/usr/local/sbin/${GATEWAY_CERTBOT_TIMER_NAME}"
    local service_unit="/etc/systemd/system/${GATEWAY_CERTBOT_TIMER_NAME}.service"
    local timer_unit="/etc/systemd/system/${GATEWAY_CERTBOT_TIMER_NAME}.timer"
    run_privileged mkdir -p /usr/local/sbin /etc/systemd/system
    printf '%s\n' '#!/bin/sh' 'set -eu' \
        "\"$CERTBOT_BIN\" renew --quiet --deploy-hook \"$SYSTEMCTL_BIN reload nginx\"" |
        run_privileged tee "$renew_script" >/dev/null
    run_privileged chmod 0755 "$renew_script"
    printf '%s\n' '[Unit]' 'Description=Renew managed Nginx TLS certificates' \
        'After=network-online.target' '[Service]' 'Type=oneshot' "ExecStart=$renew_script" |
        run_privileged tee "$service_unit" >/dev/null
    printf '%s\n' '[Unit]' 'Description=Renew managed Nginx TLS certificates daily' '[Timer]' \
        "OnCalendar=$GATEWAY_RENEW_ON_CALENDAR" "RandomizedDelaySec=$GATEWAY_RENEW_RANDOM_DELAY" \
        'Persistent=true' '[Install]' 'WantedBy=timers.target' |
        run_privileged tee "$timer_unit" >/dev/null
    run_privileged "$SYSTEMCTL_BIN" disable --now certbot.timer >/dev/null 2>&1 || true
    run_privileged "$SYSTEMCTL_BIN" daemon-reload
    run_privileged "$SYSTEMCTL_BIN" enable --now "${GATEWAY_CERTBOT_TIMER_NAME}.timer"
}

if [ "$has_certbot_site" -eq 1 ]; then
    install_certbot || exit 1
fi
if [ "${#MISSING_CERT_SITE_ENV_FILES[@]}" -gt 0 ]; then
    : "${CERTBOT_EMAIL:?CERTBOT_EMAIL is required when a managed TLS site has no certificate}"
    for site_env in "${MISSING_CERT_SITE_ENV_FILES[@]}"; do
        load_site "$site_env"
        install_staged_config "$STAGED_BOOTSTRAP_DIR/$SITE_CONFIG_FILE" "$SITE_CONFIG_FILE" \
            || { rollback; exit 1; }
    done
    validate_and_reload || exit 1
    for site_env in "${MISSING_CERT_SITE_ENV_FILES[@]}"; do
        load_site "$site_env"
        run_privileged "$CERTBOT_BIN" certonly --webroot --webroot-path "$GATEWAY_WEBROOT_PATH" \
            --non-interactive --agree-tos --email "$CERTBOT_EMAIL" --domain "$SITE_DOMAIN" \
            --keep-until-expiring || { rollback; exit 1; }
        for certificate in "$SITE_CERT_DIR/fullchain.pem" "$SITE_CERT_DIR/privkey.pem"; do
            [ -s "$certificate" ] || { echo "Certbot did not create $certificate" >&2; rollback; exit 1; }
        done
    done
fi
if [ "$has_certbot_site" -eq 1 ]; then
    configure_renewal_timer || { rollback; exit 1; }
fi

for site_env in "${SITE_ENV_FILES[@]}"; do
    load_site "$site_env"
    install_staged_config "$STAGED_SITES_DIR/$SITE_CONFIG_FILE" "$SITE_CONFIG_FILE" \
        || { rollback; exit 1; }
done

is_desired_config() {
    local candidate="$1"
    local desired
    for desired in "${DESIRED_CONFIG_NAMES[@]}"; do
        [ "$candidate" = "$desired" ] && return 0
    done
    return 1
}
for config_name in "${PREVIOUS_CONFIG_NAMES[@]}"; do
    is_desired_config "$config_name" || run_privileged rm -f "$GATEWAY_CONFIG_DIR/$config_name"
done
manifest_next="${GATEWAY_MANIFEST_PATH}.next"
printf '%s\n' "${DESIRED_CONFIG_NAMES[@]}" | sort | run_privileged tee "$manifest_next" >/dev/null
run_privileged mv "$manifest_next" "$GATEWAY_MANIFEST_PATH" || { rollback; exit 1; }
validate_and_reload || exit 1

check_site_health() {
    local site_env="$1"
    local protocol=http
    local port=80
    local health_path
    local curl_extra=(--resolve)
    load_site "$site_env"
    [ "$SITE_HEALTH_CHECK_REQUIRED" = "true" ] || return 0
    if [ "$SITE_TLS_ENABLED" = "true" ]; then protocol=https; port=443; curl_extra+=(--insecure); fi
    curl_extra+=("${SITE_DOMAIN}:${port}:127.0.0.1")
    for health_path in "$SITE_HEALTH_PATH" "$SITE_API_HEALTH_PATH"; do
        [ -n "$health_path" ] || continue
        curl --fail --silent --show-error --max-time 15 "${curl_extra[@]}" \
            "${protocol}://${SITE_DOMAIN}${health_path}" >/dev/null || {
            echo "Health check failed for $SITE_NAME: ${protocol}://${SITE_DOMAIN}${health_path}" >&2
            return 1
        }
    done
}
for site_env in "${SITE_ENV_FILES[@]}"; do
    check_site_health "$site_env" || { rollback; exit 1; }
done

run_privileged "$SYSTEMCTL_BIN" --no-pager --full status nginx || true
if [ "$has_certbot_site" -eq 1 ]; then
    run_privileged "$SYSTEMCTL_BIN" --no-pager --full status "${GATEWAY_CERTBOT_TIMER_NAME}.timer" || true
fi
