#!/usr/bin/env bash
# Install the staged host Nginx configuration, bootstrap Certbot when needed,
# configure renewal, and roll back on validation or required health failures.

set -Eeuo pipefail

: "${NGINX_DOMAIN:?NGINX_DOMAIN is required}"
: "${NGINX_CONFIG_PATH:?NGINX_CONFIG_PATH is required}"
: "${NGINX_STAGING_PATH:?NGINX_STAGING_PATH is required}"
: "${NGINX_BOOTSTRAP_PATH:?NGINX_BOOTSTRAP_PATH is required}"
: "${NGINX_DEPLOY_SCRIPT_PATH:?NGINX_DEPLOY_SCRIPT_PATH is required}"
: "${NGINX_WEBROOT_PATH:?NGINX_WEBROOT_PATH is required}"
: "${NGINX_CERT_DIR:?NGINX_CERT_DIR is required}"
: "${NGINX_TIMER_NAME:?NGINX_TIMER_NAME is required}"
: "${NGINX_RENEW_ON_CALENDAR:?NGINX_RENEW_ON_CALENDAR is required}"
: "${NGINX_RENEW_RANDOM_DELAY:?NGINX_RENEW_RANDOM_DELAY is required}"
: "${NGINX_HEALTH_PATH:?NGINX_HEALTH_PATH is required}"
: "${NGINX_API_HEALTH_PATH:?NGINX_API_HEALTH_PATH is required}"
: "${NGINX_HEALTH_CHECK_REQUIRED:?NGINX_HEALTH_CHECK_REQUIRED is required}"

case "$NGINX_HEALTH_CHECK_REQUIRED" in
    true|false) ;;
    *)
        echo "NGINX_HEALTH_CHECK_REQUIRED must be true or false." >&2
        exit 1
        ;;
esac
case "$NGINX_HEALTH_PATH:$NGINX_API_HEALTH_PATH" in
    /*:/*) ;;
    *)
        echo "Health paths must start with /." >&2
        exit 1
        ;;
esac
case "$NGINX_RENEW_RANDOM_DELAY" in
    ''|*[!0-9smhd]*)
        echo "NGINX_RENEW_RANDOM_DELAY must use a systemd duration such as 30m." >&2
        exit 1
        ;;
esac
for config_value in \
    "$NGINX_DOMAIN" "$NGINX_CONFIG_PATH" "$NGINX_STAGING_PATH" \
    "$NGINX_BOOTSTRAP_PATH" "$NGINX_DEPLOY_SCRIPT_PATH" "$NGINX_WEBROOT_PATH" \
    "$NGINX_CERT_DIR" "$NGINX_TIMER_NAME" "$NGINX_RENEW_ON_CALENDAR" \
    "$NGINX_RENEW_RANDOM_DELAY" "$NGINX_HEALTH_PATH" "$NGINX_API_HEALTH_PATH"; do
    case "$config_value" in
        *$'\n'*|*$'\r'*)
            echo "Deployment settings must not contain a newline." >&2
            exit 1
            ;;
    esac
done

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
if [ -z "$NGINX_BIN" ]; then
    echo "nginx executable not found on the server." >&2
    exit 1
fi
if [ -z "$SYSTEMCTL_BIN" ]; then
    echo "systemctl executable not found on the server." >&2
    exit 1
fi

case "$NGINX_TIMER_NAME" in
    *[!A-Za-z0-9_.@-]*|'')
        echo "NGINX_TIMER_NAME contains unsupported characters." >&2
        exit 1
        ;;
esac

backup_path="${NGINX_CONFIG_PATH}.previous"
next_path="${NGINX_CONFIG_PATH}.next"
service_unit="/etc/systemd/system/${NGINX_TIMER_NAME}.service"
timer_unit="/etc/systemd/system/${NGINX_TIMER_NAME}.timer"

cleanup() {
    rm -f \
        "$NGINX_STAGING_PATH" \
        "$NGINX_BOOTSTRAP_PATH" \
        "$NGINX_DEPLOY_SCRIPT_PATH"
    run_privileged rm -f "$next_path" || true
}
trap cleanup EXIT

run_privileged mkdir -p "$(dirname "$NGINX_CONFIG_PATH")"

if [ -f "$NGINX_CONFIG_PATH" ]; then
    run_privileged cp -p "$NGINX_CONFIG_PATH" "$backup_path"
else
    run_privileged rm -f "$backup_path"
fi

rollback() {
    echo "Restoring the previous Nginx configuration..."
    if [ -f "$backup_path" ]; then
        run_privileged install -m 0644 "$backup_path" "$NGINX_CONFIG_PATH"
    else
        run_privileged rm -f "$NGINX_CONFIG_PATH"
    fi
    run_privileged "$NGINX_BIN" -t || true
    run_privileged "$SYSTEMCTL_BIN" reload-or-restart nginx || true
}

install_and_reload() {
    local source_path="$1"

    if [ ! -f "$source_path" ]; then
        echo "Staged Nginx configuration not found: $source_path" >&2
        return 1
    fi

    run_privileged install -m 0644 "$source_path" "$next_path"
    run_privileged mv "$next_path" "$NGINX_CONFIG_PATH"

    if ! run_privileged "$NGINX_BIN" -t; then
        rollback
        return 1
    fi

    if ! run_privileged "$SYSTEMCTL_BIN" reload-or-restart nginx; then
        rollback
        return 1
    fi
}

install_certbot() {
    local certbot_bin
    certbot_bin="$(command -v certbot || true)"
    if [ -n "$certbot_bin" ]; then
        CERTBOT_BIN="$certbot_bin"
        return 0
    fi

    echo "Certbot is missing; installing it with the available package manager..."
    if command -v apt-get >/dev/null 2>&1; then
        run_privileged apt-get update
        run_privileged apt-get install -y certbot
    elif command -v dnf >/dev/null 2>&1; then
        run_privileged dnf install -y certbot
    elif command -v yum >/dev/null 2>&1; then
        run_privileged yum install -y certbot
    else
        echo "No supported package manager was found for Certbot." >&2
        return 1
    fi

    CERTBOT_BIN="$(command -v certbot || true)"
    if [ -z "$CERTBOT_BIN" ]; then
        echo "Certbot installation completed but the executable was not found." >&2
        return 1
    fi
}

configure_renewal_timer() {
    local renew_script="/usr/local/sbin/${NGINX_TIMER_NAME}"

    run_privileged mkdir -p /usr/local/sbin /etc/systemd/system

    printf '%s\n' \
        '#!/bin/sh' \
        'set -eu' \
        "\"$CERTBOT_BIN\" renew --quiet --deploy-hook \"$SYSTEMCTL_BIN reload nginx\"" |
        run_privileged tee "$renew_script" >/dev/null
    run_privileged chmod 0755 "$renew_script"

    printf '%s\n' \
        '[Unit]' \
        'Description=Renew ERP settlement TLS certificate' \
        'After=network-online.target' \
        '[Service]' \
        'Type=oneshot' \
        "ExecStart=$renew_script" |
        run_privileged tee "$service_unit" >/dev/null

    printf '%s\n' \
        '[Unit]' \
        'Description=Daily ERP settlement TLS certificate renewal' \
        '[Timer]' \
        "OnCalendar=$NGINX_RENEW_ON_CALENDAR" \
        "RandomizedDelaySec=$NGINX_RENEW_RANDOM_DELAY" \
        'Persistent=true' \
        '[Install]' \
        'WantedBy=timers.target' |
        run_privileged tee "$timer_unit" >/dev/null

    run_privileged "$SYSTEMCTL_BIN" disable --now certbot.timer >/dev/null 2>&1 || true
    run_privileged "$SYSTEMCTL_BIN" daemon-reload
    run_privileged "$SYSTEMCTL_BIN" enable --now "${NGINX_TIMER_NAME}.timer"
}

has_certificate=1
for certificate in "$NGINX_CERT_DIR/fullchain.pem" "$NGINX_CERT_DIR/privkey.pem"; do
    if [ ! -s "$certificate" ]; then
        has_certificate=0
    fi
done

install_certbot

if [ "$has_certificate" -eq 0 ]; then
    : "${CERTBOT_EMAIL:?CERTBOT_EMAIL is required for the first certificate request}"
    run_privileged mkdir -p "$NGINX_WEBROOT_PATH"

    if ! install_and_reload "$NGINX_BOOTSTRAP_PATH"; then
        exit 1
    fi

    if ! run_privileged "$CERTBOT_BIN" certonly \
        --webroot \
        --webroot-path "$NGINX_WEBROOT_PATH" \
        --non-interactive \
        --agree-tos \
        --email "$CERTBOT_EMAIL" \
        --domain "$NGINX_DOMAIN" \
        --keep-until-expiring; then
        rollback
        exit 1
    fi

    for certificate in "$NGINX_CERT_DIR/fullchain.pem" "$NGINX_CERT_DIR/privkey.pem"; do
        if [ ! -s "$certificate" ]; then
            echo "Certbot finished without creating $certificate" >&2
            rollback
            exit 1
        fi
    done

    # The bootstrap configuration is now the last known-good state.
    run_privileged cp -p "$NGINX_CONFIG_PATH" "$backup_path"
fi

if ! configure_renewal_timer; then
    rollback
    exit 1
fi

if ! install_and_reload "$NGINX_STAGING_PATH"; then
    exit 1
fi

frontend_url="https://${NGINX_DOMAIN}${NGINX_HEALTH_PATH}"
api_url="https://${NGINX_DOMAIN}${NGINX_API_HEALTH_PATH}"
if curl --fail --silent --show-error --insecure --max-time 15 \
    --resolve "${NGINX_DOMAIN}:443:127.0.0.1" "$frontend_url" >/dev/null \
    && curl --fail --silent --show-error --insecure --max-time 15 \
    --resolve "${NGINX_DOMAIN}:443:127.0.0.1" "$api_url" >/dev/null; then
    echo "HTTPS frontend/API are reachable and certificate renewal is scheduled."
elif [ "$NGINX_HEALTH_CHECK_REQUIRED" = "true" ]; then
    echo "HTTPS frontend/API health check failed." >&2
    run_privileged "$SYSTEMCTL_BIN" --no-pager --full status nginx || true
    rollback
    exit 1
else
    echo "Nginx deployed, but the HTTPS frontend/API health check failed." >&2
    echo "NGINX_HEALTH_CHECK_REQUIRED=false, so deployment remains successful." >&2
fi

run_privileged "$SYSTEMCTL_BIN" --no-pager --full status nginx || true
run_privileged "$SYSTEMCTL_BIN" --no-pager --full status "${NGINX_TIMER_NAME}.timer" || true
