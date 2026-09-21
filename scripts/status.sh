#!/usr/bin/env bash
# Show the host Nginx status and listening ports.

set -Eeuo pipefail

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

run_privileged systemctl --no-pager --full status nginx || true
echo
echo "Listening ports:"
ss -ltnp | grep -E ':(80|443)\b' || true
echo
echo "ERP frontend upstream:"
curl --silent --show-error --max-time 10 \
    --header 'Host: erp.lytt.fun' \
    --head http://127.0.0.1:8080/login || true
