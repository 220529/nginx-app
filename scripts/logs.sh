#!/usr/bin/env bash
# Show host Nginx logs.
# Usage: ./logs.sh [access|error|system] [lines]

set -Eeuo pipefail

LOG_TYPE="${1:-error}"
LINES="${2:-100}"

run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

case "$LOG_TYPE" in
    access)
        run_privileged tail -n "$LINES" /var/log/nginx/access.log
        ;;
    error)
        run_privileged tail -n "$LINES" /var/log/nginx/error.log
        ;;
    system)
        run_privileged journalctl -u nginx -n "$LINES" --no-pager
        ;;
    *)
        echo "Usage: $0 [access|error|system] [lines]" >&2
        exit 2
        ;;
esac
