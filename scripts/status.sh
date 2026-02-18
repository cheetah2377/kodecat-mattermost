#!/usr/bin/env bash
# =============================================================================
# Check Mattermost service health status
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"

check_docker
load_env

echo -e "${BOLD}Mattermost Stack Status${RESET}"
echo "================================================"
echo ""

# Docker Compose service status
log "Service status:"
${DC} ps
echo ""

# Health check
log "Health check:"
DOMAIN="${MM_DOMAIN:-chat.kodeme.io}"
if command -v curl &>/dev/null; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        ok "Mattermost is healthy (https://${DOMAIN} -> ${HTTP_CODE})"
    else
        warn "Mattermost health check returned: ${HTTP_CODE}"
    fi
else
    warn "curl not available, skipping HTTP health check"
fi
echo ""

# Database check
log "Database status:"
DB_CONTAINER="${COMPOSE_PROJECT_NAME:-mattermost}-mm-postgres-1"
if docker exec "$DB_CONTAINER" pg_isready -q 2>/dev/null; then
    ok "PostgreSQL is ready"
else
    warn "PostgreSQL not reachable"
fi
echo ""

# Resource usage
log "Resource usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
    $(${DC} ps -q 2>/dev/null) 2>/dev/null || warn "Could not fetch resource stats"
