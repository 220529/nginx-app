#!/usr/bin/env bash
# Renew certificates and reload host Nginx when a certificate changes.

set -Eeuo pipefail

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

run_privileged certbot renew --quiet --deploy-hook "systemctl reload nginx"
