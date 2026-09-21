#!/usr/bin/env bash
# Start the host Nginx service after validating its configuration.

set -Eeuo pipefail

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

run_privileged nginx -t
run_privileged systemctl enable --now nginx
run_privileged systemctl reload nginx
run_privileged systemctl --no-pager --full status nginx
