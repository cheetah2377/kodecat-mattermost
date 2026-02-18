#!/usr/bin/env bash
# =============================================================================
# Tail Mattermost service logs
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"

check_docker

SERVICE="${1:-}"
LINES="${2:-100}"

if [ -n "$SERVICE" ]; then
    log "Tailing logs for: ${SERVICE} (last ${LINES} lines)"
    ${DC} logs -f --tail="${LINES}" "${SERVICE}"
else
    log "Tailing logs for all services (last ${LINES} lines)"
    ${DC} logs -f --tail="${LINES}"
fi
