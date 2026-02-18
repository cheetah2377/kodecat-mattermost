#!/bin/sh
# Mattermost Maintenance & Cleanup
# Usage: /scripts/maintenance.sh [command] [args]
# Runs inside container with mmctl --local
set -e

CMD="${1:-status}"
ARG1="$2"
ARG2="$3"

# mmctl helpers
mmctl_cmd() { /mattermost/bin/mmctl --local "$@"; }
mmctl_json() { /mattermost/bin/mmctl --local --format json "$@" 2>/dev/null; }
mmctl_quiet() { /mattermost/bin/mmctl --local --quiet "$@" 2>/dev/null; }

# Formatted output
print_header() {
    echo ""
    echo "=============================================================="
    echo "                    $1"
    echo "=============================================================="
}

print_section() {
    echo ""
    echo "-- $1 --"
}

case "$CMD" in
# STATUS
status)
    print_header "System Status"
    mmctl_cmd system status
    ;;

version)
    print_header "Version Information"
    mmctl_cmd version

    print_section "Server Version"
    mmctl_json version | grep -o '"Version":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "Unknown"
    ;;

license)
    print_header "License Information"
    mmctl_cmd license show 2>/dev/null || echo "No license installed (Team Edition)"
    ;;

uptime)
    print_header "System Uptime"
    mmctl_cmd system status | grep -i uptime || echo "Uptime information not available"
    ;;

# CACHE
cache)
    [ -z "$ARG1" ] && { echo "Usage: $0 cache <clear|stats|invalidate>"; exit 1; }
    case "$ARG1" in
    clear)
        print_header "Clear All Caches"
        mmctl_cmd cache clear
        echo "Caches cleared"
        ;;
    stats)
        print_header "Cache Statistics"
        echo "Cache statistics available in System Console"
        echo "Or via Prometheus metrics endpoint"
        ;;
    invalidate)
        print_header "Invalidate Caches"
        mmctl_cmd cache clear
        echo "Caches invalidated"
        ;;
    *)
        echo "Usage: $0 cache <clear|stats|invalidate>"
        ;;
    esac
    ;;

# CLEANUP
sessions)
    [ -z "$ARG1" ] && { echo "Usage: $0 sessions <cleanup|cleanup --all>"; exit 1; }
    case "$ARG1" in
    cleanup)
        print_header "Clean Expired Sessions"
        if [ "$ARG2" = "--all" ]; then
            echo "Revoking ALL sessions..."
            mmctl_cmd user logout --all
            echo "All sessions revoked"
        else
            echo "Session cleanup is handled automatically"
            echo "Use 'cleanup --all' to revoke all sessions"
        fi
        ;;
    *)
        echo "Usage: $0 sessions <cleanup|cleanup --all>"
        ;;
    esac
    ;;

tokens)
    [ -z "$ARG1" ] && { echo "Usage: $0 tokens cleanup"; exit 1; }
    case "$ARG1" in
    cleanup)
        print_header "Clean Expired Tokens"
        echo "Token cleanup is handled automatically by the server"
        echo ""
        echo "To manually revoke tokens:"
        echo "  /scripts/users.sh tokens revoke <user> <token_id>"
        ;;
    *)
        echo "Usage: $0 tokens cleanup"
        ;;
    esac
    ;;

reactions)
    [ -z "$ARG1" ] && { echo "Usage: $0 reactions cleanup"; exit 1; }
    case "$ARG1" in
    cleanup)
        print_header "Clean Orphan Reactions"
        echo "Orphan reactions are cleaned during data retention jobs"
        echo ""
        echo "To run data retention:"
        echo "  /scripts/jobs.sh by-type data_retention"
        ;;
    *)
        echo "Usage: $0 reactions cleanup"
        ;;
    esac
    ;;

attachments)
    [ -z "$ARG1" ] && { echo "Usage: $0 attachments <cleanup|list>"; exit 1; }
    case "$ARG1" in
    cleanup)
        print_header "Clean Orphan Files"
        echo "Orphan file cleanup requires careful handling"
        echo ""
        echo "Steps:"
        echo "1. Backup your data directory"
        echo "2. Use file_cleanup_job in data retention"
        echo "3. Verify files before deletion"
        ;;
    list)
        print_header "List Orphan Files"
        echo "Check /mattermost/data directory for orphan files"
        ls -la /mattermost/data/ 2>/dev/null | head -20 || echo "Cannot list data directory"
        ;;
    *)
        echo "Usage: $0 attachments <cleanup|list>"
        ;;
    esac
    ;;

jobs)
    [ -z "$ARG1" ] && { echo "Usage: $0 jobs cleanup"; exit 1; }
    case "$ARG1" in
    cleanup)
        print_header "Clean Old Job Data"
        echo "Old job data is retained for debugging"
        echo ""
        echo "To view and manage jobs:"
        echo "  /scripts/jobs.sh list"
        echo "  /scripts/jobs.sh completed"
        ;;
    *)
        echo "Usage: $0 jobs cleanup"
        ;;
    esac
    ;;

posts)
    [ -z "$ARG1" ] && { echo "Usage: $0 posts cleanup <days>"; exit 1; }
    case "$ARG1" in
    cleanup)
        [ -z "$ARG2" ] && { echo "Usage: $0 posts cleanup <days>"; exit 1; }
        print_header "Clean Old Posts"
        echo "Post cleanup requires data retention policy"
        echo ""
        echo "Requested: Delete posts older than $ARG2 days"
        echo ""
        echo "To configure data retention:"
        echo "1. Enable in System Console > Compliance"
        echo "2. Set message retention period to $ARG2 days"
        echo "3. Enable global policy"
        ;;
    *)
        echo "Usage: $0 posts cleanup <days>"
        ;;
    esac
    ;;

# DATABASE
db)
    [ -z "$ARG1" ] && { echo "Usage: $0 db <migrate|version|integrity>"; exit 1; }
    case "$ARG1" in
    migrate)
        print_header "Database Migration"
        mmctl_cmd db migrate
        ;;
    version)
        print_header "Database Version"
        mmctl_cmd db version
        ;;
    integrity)
        print_header "Database Integrity Check"
        mmctl_cmd integrity
        ;;
    *)
        echo "Usage: $0 db <migrate|version|integrity>"
        ;;
    esac
    ;;

# LOGS
logs)
    print_header "Server Logs"
    LINES="${ARG1:-100}"

    if [ "$ARG1" = "--level" ]; then
        LEVEL="${ARG2:-error}"
        echo "Filtering logs by level: $LEVEL"
        tail -n 500 /mattermost/logs/mattermost.log 2>/dev/null | grep -i "$LEVEL" | tail -n 100 || echo "No logs found"
    else
        tail -n "$LINES" /mattermost/logs/mattermost.log 2>/dev/null || echo "Cannot read log file"
    fi
    ;;

errors)
    print_header "Recent Errors"
    tail -n 1000 /mattermost/logs/mattermost.log 2>/dev/null | grep -i "error\|fatal\|panic" | tail -n 50 || echo "No errors found"
    ;;

# DISK
disk)
    print_header "Disk Usage"

    print_section "Data Directory"
    du -sh /mattermost/data 2>/dev/null || echo "Cannot access data directory"

    print_section "Logs Directory"
    du -sh /mattermost/logs 2>/dev/null || echo "Cannot access logs directory"

    print_section "Plugins Directory"
    du -sh /mattermost/plugins 2>/dev/null || echo "Cannot access plugins directory"

    print_section "Config Directory"
    du -sh /mattermost/config 2>/dev/null || echo "Cannot access config directory"
    ;;

# HEALTH
health)
    print_header "Health Check"
    /scripts/health.sh status
    ;;

# HELP
*)
    echo "Mattermost Maintenance & Cleanup"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "STATUS:"
    echo "  status                System status (default)"
    echo "  version               Show version info"
    echo "  license               Show license info"
    echo "  uptime                Show uptime"
    echo "  health                Full health check"
    echo ""
    echo "CACHE:"
    echo "  cache clear           Clear all caches"
    echo "  cache stats           Cache statistics"
    echo "  cache invalidate      Invalidate all caches"
    echo ""
    echo "CLEANUP:"
    echo "  sessions cleanup           Clean expired sessions"
    echo "  sessions cleanup --all     Clean all sessions"
    echo "  tokens cleanup             Clean expired tokens"
    echo "  reactions cleanup          Clean orphan reactions"
    echo "  attachments cleanup        Clean orphan files"
    echo "  attachments list           List orphan files"
    echo "  jobs cleanup               Clean old job data"
    echo "  posts cleanup <days>       Clean old posts"
    echo ""
    echo "DATABASE:"
    echo "  db migrate            Run database migrations"
    echo "  db version            Show database version"
    echo "  db integrity          Run integrity check"
    echo ""
    echo "LOGS:"
    echo "  logs [lines]          View server logs (default: 100)"
    echo "  logs --level <level>  Filter by log level"
    echo "  errors                Show recent errors"
    echo ""
    echo "DISK:"
    echo "  disk                  Show disk usage"
    ;;
esac
