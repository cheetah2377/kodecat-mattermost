#!/usr/bin/env bash
# =============================================================================
# Deploy/Redeploy Mattermost via Docker Compose
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"

check_docker

case "${1:-up}" in
    up|start)
        log "Deploying Mattermost stack..."
        ${DC} up -d --build
        ok "Mattermost stack deployed"
        echo ""
        log "Checking service health..."
        sleep 5
        ${DC} ps
        ;;
    down|stop)
        if confirm "Stop all Mattermost services?"; then
            ${DC} down
            ok "Mattermost stack stopped"
        fi
        ;;
    restart)
        log "Restarting Mattermost stack..."
        ${DC} restart
        ok "Mattermost stack restarted"
        ;;
    rebuild)
        log "Rebuilding and redeploying..."
        ${DC} up -d --build --force-recreate
        ok "Mattermost stack rebuilt and deployed"
        ;;
    pull)
        log "Pulling latest images..."
        ${DC} pull
        ok "Images pulled"
        ;;
    *)
        echo "Usage: deploy.sh [up|down|restart|rebuild|pull]"
        exit 1
        ;;
esac
