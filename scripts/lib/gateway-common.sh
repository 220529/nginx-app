#!/usr/bin/env bash

# Shared configuration and validation helpers for the gateway tools.

validate_no_newline() {
    local value_name="$1"
    local value="$2"

    case "$value" in
        *$'\n'*|*$'\r'*)
            echo "$value_name must not contain a newline." >&2
            exit 1
            ;;
    esac
}

validate_boolean() {
    local value_name="$1"
    local value="$2"

    case "$value" in
        true|false) ;;
        *)
            echo "$value_name must be true or false." >&2
            exit 1
            ;;
    esac
}

validate_config_filename() {
    local config_name="$1"

    case "$config_name" in
        ''|*[!A-Za-z0-9._-]*)
            echo "Invalid managed configuration filename: $config_name" >&2
            exit 1
            ;;
    esac
    case "$config_name" in
        *.conf) ;;
        *)
            echo "Managed configuration filename must end with .conf: $config_name" >&2
            exit 1
            ;;
    esac
}

validate_gateway_settings() {
    : "${GATEWAY_TAG_PREFIX:?GATEWAY_TAG_PREFIX is required}"
    : "${GATEWAY_STAGING_DIR:?GATEWAY_STAGING_DIR is required}"
    : "${GATEWAY_CONFIG_DIR:?GATEWAY_CONFIG_DIR is required}"
    : "${GATEWAY_MANIFEST_PATH:?GATEWAY_MANIFEST_PATH is required}"
    : "${GATEWAY_BACKUP_DIR:?GATEWAY_BACKUP_DIR is required}"
    : "${GATEWAY_WEBROOT_PATH:?GATEWAY_WEBROOT_PATH is required}"
    : "${GATEWAY_CERTBOT_TIMER_NAME:?GATEWAY_CERTBOT_TIMER_NAME is required}"
    : "${GATEWAY_RENEW_ON_CALENDAR:?GATEWAY_RENEW_ON_CALENDAR is required}"
    : "${GATEWAY_RENEW_RANDOM_DELAY:?GATEWAY_RENEW_RANDOM_DELAY is required}"

    validate_no_newline GATEWAY_TAG_PREFIX "$GATEWAY_TAG_PREFIX"
    case "$GATEWAY_TAG_PREFIX" in
        ''|*[!A-Za-z0-9._/-]*|/*|*/)
            echo "Invalid GATEWAY_TAG_PREFIX: $GATEWAY_TAG_PREFIX" >&2
            exit 1
            ;;
    esac
    case "$GATEWAY_TAG_PREFIX" in
        */*) ;;
        *)
            echo "GATEWAY_TAG_PREFIX must include a branch prefix, for example master/nginx-app." >&2
            exit 1
            ;;
    esac
    for path_name in GATEWAY_STAGING_DIR GATEWAY_CONFIG_DIR GATEWAY_MANIFEST_PATH GATEWAY_BACKUP_DIR GATEWAY_WEBROOT_PATH; do
        local path_value="${!path_name}"
        validate_no_newline "$path_name" "$path_value"
        case "$path_value" in
            /*) ;;
            *)
                echo "$path_name must be an absolute path." >&2
                exit 1
                ;;
        esac
    done
    validate_no_newline GATEWAY_RENEW_ON_CALENDAR "$GATEWAY_RENEW_ON_CALENDAR"
    case "$GATEWAY_CERTBOT_TIMER_NAME" in
        ''|*[!A-Za-z0-9_.@-]*)
            echo "Invalid GATEWAY_CERTBOT_TIMER_NAME: $GATEWAY_CERTBOT_TIMER_NAME" >&2
            exit 1
            ;;
    esac
    case "$GATEWAY_RENEW_RANDOM_DELAY" in
        ''|*[!0-9smhd]*)
            echo "GATEWAY_RENEW_RANDOM_DELAY must use a systemd duration such as 30m." >&2
            exit 1
            ;;
    esac
    case "$GATEWAY_WEBROOT_PATH" in
        /*) ;;
        *)
            echo "GATEWAY_WEBROOT_PATH must be an absolute path." >&2
            exit 1
            ;;
    esac
}

load_site_config() {
    local site_env="$1"

    unset \
        SITE_NAME SITE_DOMAIN SITE_CONFIG_FILE SITE_UPSTREAM_URL \
        SITE_TLS_ENABLED SITE_CERTBOT_ENABLED SITE_CERT_DIR \
        SITE_HEALTH_PATH SITE_API_HEALTH_PATH SITE_HEALTH_CHECK_REQUIRED

    set -a
    # shellcheck disable=SC1090
    . "$site_env"
    set +a

    : "${SITE_NAME:?SITE_NAME is required in $site_env}"
    : "${SITE_DOMAIN:?SITE_DOMAIN is required in $site_env}"
    : "${SITE_UPSTREAM_URL:?SITE_UPSTREAM_URL is required in $site_env}"

    SITE_CONFIG_FILE="${SITE_CONFIG_FILE:-${SITE_NAME}.conf}"
    SITE_TLS_ENABLED="${SITE_TLS_ENABLED:-true}"
    SITE_CERTBOT_ENABLED="${SITE_CERTBOT_ENABLED:-$SITE_TLS_ENABLED}"
    SITE_CERT_DIR="${SITE_CERT_DIR:-/etc/letsencrypt/live/$SITE_DOMAIN}"
    SITE_HEALTH_PATH="${SITE_HEALTH_PATH:-}"
    SITE_API_HEALTH_PATH="${SITE_API_HEALTH_PATH:-}"
    SITE_HEALTH_CHECK_REQUIRED="${SITE_HEALTH_CHECK_REQUIRED:-false}"

    validate_no_newline SITE_NAME "$SITE_NAME"
    validate_no_newline SITE_DOMAIN "$SITE_DOMAIN"
    validate_no_newline SITE_CONFIG_FILE "$SITE_CONFIG_FILE"
    validate_no_newline SITE_UPSTREAM_URL "$SITE_UPSTREAM_URL"
    validate_no_newline SITE_CERT_DIR "$SITE_CERT_DIR"
    validate_no_newline SITE_HEALTH_PATH "$SITE_HEALTH_PATH"
    validate_no_newline SITE_API_HEALTH_PATH "$SITE_API_HEALTH_PATH"

    case "$SITE_NAME" in
        ''|*[!A-Za-z0-9._-]*)
            echo "Invalid SITE_NAME in $site_env: $SITE_NAME" >&2
            exit 1
            ;;
    esac
    case "$SITE_DOMAIN" in
        ''|*[!A-Za-z0-9.-]*)
            echo "Invalid SITE_DOMAIN in $site_env: $SITE_DOMAIN" >&2
            exit 1
            ;;
    esac
    validate_config_filename "$SITE_CONFIG_FILE"
    case "$SITE_UPSTREAM_URL" in
        http://*|https://*) ;;
        *)
            echo "SITE_UPSTREAM_URL must start with http:// or https:// in $site_env." >&2
            exit 1
            ;;
    esac
    case "$SITE_UPSTREAM_URL" in
        *[[:space:]]*)
            echo "SITE_UPSTREAM_URL must not contain whitespace in $site_env." >&2
            exit 1
            ;;
    esac
    case "$SITE_CERT_DIR" in
        /*) ;;
        *)
            echo "SITE_CERT_DIR must be an absolute path in $site_env." >&2
            exit 1
            ;;
    esac
    case "$SITE_CERT_DIR" in
        *[[:space:]]*)
            echo "SITE_CERT_DIR must not contain whitespace in $site_env." >&2
            exit 1
            ;;
    esac

    validate_boolean SITE_TLS_ENABLED "$SITE_TLS_ENABLED"
    validate_boolean SITE_CERTBOT_ENABLED "$SITE_CERTBOT_ENABLED"
    validate_boolean SITE_HEALTH_CHECK_REQUIRED "$SITE_HEALTH_CHECK_REQUIRED"

    if [ "$SITE_HEALTH_CHECK_REQUIRED" = "true" ] \
        && [ -z "$SITE_HEALTH_PATH" ] \
        && [ -z "$SITE_API_HEALTH_PATH" ]; then
        echo "At least one health path is required when SITE_HEALTH_CHECK_REQUIRED=true in $site_env." >&2
        exit 1
    fi

    for path_name in SITE_HEALTH_PATH SITE_API_HEALTH_PATH; do
        local path_value="${!path_name}"
        if [ -n "$path_value" ]; then
            case "$path_value" in
                /*) ;;
                *)
                    echo "$path_name must start with / in $site_env." >&2
                    exit 1
                    ;;
            esac
        fi
    done
}
