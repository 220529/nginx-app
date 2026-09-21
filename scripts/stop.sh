#!/usr/bin/env bash
# Stop only the host Nginx gateway. Application containers are managed by the
# erp-settlement-thesis project.

set -Eeuo pipefail

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

run_privileged systemctl stop nginx
run_privileged systemctl --no-pager --full status nginx || true
