#!/usr/bin/env bash
# =============================================================================
# Mattermost CLI — Main entry point for all management operations
# =============================================================================
# Dispatches to:
#   - Container scripts (via docker exec into mattermost container)
#   - Host scripts (status, logs, deploy, backup)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"

# Mattermost container name
MM_CONTAINER="${COMPOSE_PROJECT_NAME:-mattermost}-mattermost-1"

# Execute a script inside the mattermost container
container_exec() {
    local script="$1"
    shift
    check_docker
    docker exec -it "$MM_CONTAINER" /bin/sh "/scripts/${script}" "$@"
}

usage() {
    echo -e "${BOLD}Mattermost CLI — Management Toolkit${RESET}"
    echo ""
    echo -e "Usage: ${BOLD}$(basename "$0")${RESET} <command> [options]"
    echo ""
    echo -e "${BOLD}Host Commands:${RESET}"
    echo "  status        Check service health status"
    echo "  logs          Tail service logs"
    echo "  deploy        Deploy/redeploy via Docker Compose"
    echo "  backup        Trigger S3 database backup"
    echo "  restore       Restore from S3 backup"
    echo ""
    echo -e "${BOLD}Container Commands (Mattermost):${RESET}"
    echo "  health        Health check with 0-100 scoring"
    echo "  dashboard     Real-time system dashboard"
    echo "  users         User lifecycle management"
    echo "  teams         Team management"
    echo "  channels      Channel management"
    echo "  permissions   Role/permission management"
    echo "  posts         Post/message management"
    echo "  config        Configuration management"
    echo "  maintenance   Cleanup/maintenance operations"
    echo "  webhooks      Webhook management"
    echo "  bots          Bot management"
    echo "  plugins       Plugin management"
    echo "  integrations  LDAP/SAML/OAuth integrations"
    echo "  jobs          Background job monitoring"
    echo "  audit         Audit/compliance logs"
    echo "  import-export Bulk import/export"
    echo ""
    echo -e "${BOLD}Examples:${RESET}"
    echo "  $(basename "$0") status"
    echo "  $(basename "$0") logs mattermost"
    echo "  $(basename "$0") deploy"
    echo "  $(basename "$0") health quick"
    echo "  $(basename "$0") users list --all"
    echo "  $(basename "$0") teams list"
    echo "  $(basename "$0") backup"
    echo "  $(basename "$0") restore daily/mattermost-20250101-120000.sql.gz"
}

case "${1:-}" in
    # Host-side commands
    status)
        shift
        exec bash "${SCRIPT_DIR}/status.sh" "$@"
        ;;
    logs)
        shift
        exec bash "${SCRIPT_DIR}/logs.sh" "$@"
        ;;
    deploy)
        shift
        exec bash "${SCRIPT_DIR}/deploy.sh" "$@"
        ;;
    backup)
        shift
        source "${SCRIPT_DIR}/lib/config.sh"
        check_docker
        BACKUP_CONTAINER="${COMPOSE_PROJECT_NAME:-mattermost}-mm-backup-1"
        log "Triggering manual backup..."
        docker exec "$BACKUP_CONTAINER" backup.sh backup
        ok "Backup complete"
        ;;
    restore)
        shift
        source "${SCRIPT_DIR}/lib/config.sh"
        check_docker
        BACKUP_CONTAINER="${COMPOSE_PROJECT_NAME:-mattermost}-mm-backup-1"
        S3_KEY="${1:-}"
        if [ -z "$S3_KEY" ]; then
            log "Available backups:"
            docker exec "$BACKUP_CONTAINER" backup.sh restore
            exit 1
        fi
        if confirm "Restore database from ${S3_KEY}? This will overwrite current data."; then
            docker exec "$BACKUP_CONTAINER" backup.sh restore "$S3_KEY"
            ok "Restore complete"
            log "Restarting Mattermost to pick up restored data..."
            ${DC} restart mattermost
            ok "Mattermost restarted"
        fi
        ;;
    # Container-side commands (dispatched via docker exec)
    health)
        shift
        container_exec "health.sh" "$@"
        ;;
    dashboard)
        shift
        container_exec "dashboard.sh" "$@"
        ;;
    users)
        shift
        container_exec "users.sh" "$@"
        ;;
    teams)
        shift
        container_exec "teams.sh" "$@"
        ;;
    channels)
        shift
        container_exec "channels.sh" "$@"
        ;;
    permissions)
        shift
        container_exec "permissions.sh" "$@"
        ;;
    posts)
        shift
        container_exec "posts.sh" "$@"
        ;;
    config)
        shift
        container_exec "config.sh" "$@"
        ;;
    maintenance)
        shift
        container_exec "maintenance.sh" "$@"
        ;;
    webhooks)
        shift
        container_exec "webhooks.sh" "$@"
        ;;
    bots)
        shift
        container_exec "bots.sh" "$@"
        ;;
    plugins)
        shift
        container_exec "plugins.sh" "$@"
        ;;
    integrations)
        shift
        container_exec "integrations.sh" "$@"
        ;;
    jobs)
        shift
        container_exec "jobs.sh" "$@"
        ;;
    audit)
        shift
        container_exec "audit.sh" "$@"
        ;;
    import-export)
        shift
        container_exec "import-export.sh" "$@"
        ;;
    help|--help|-h|"")
        usage
        ;;
    *)
        err "Unknown command: $1"
        echo ""
        usage
        exit 1
        ;;
esac
