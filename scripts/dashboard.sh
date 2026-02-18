#!/bin/sh
# Mattermost Dashboard
# Usage: /scripts/dashboard.sh [command]
# Runs inside container with mmctl --local
set -e

CMD="${1:-summary}"
WATCH_INTERVAL="${2:-5}"

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

# Calculate health score
calculate_score() {
    SCORE=100
    STATUS=$(mmctl_json system status 2>/dev/null || echo '{"status":"error"}')

    DB_STATUS=$(echo "$STATUS" | grep -o '"DatabaseStatus":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "error")
    if [ "$DB_STATUS" != "OK" ]; then
        SCORE=$((SCORE - 40))
    fi

    FS_STATUS=$(echo "$STATUS" | grep -o '"FileStoreStatus":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "error")
    if [ "$FS_STATUS" != "OK" ]; then
        SCORE=$((SCORE - 20))
    fi

    if [ "$SCORE" -lt 0 ]; then
        SCORE=0
    fi

    echo "$SCORE"
}

score_status() {
    SCORE=$1
    if [ "$SCORE" -ge 90 ]; then
        echo "HEALTHY"
    elif [ "$SCORE" -ge 70 ]; then
        echo "WARNING"
    elif [ "$SCORE" -ge 50 ]; then
        echo "DEGRADED"
    else
        echo "CRITICAL"
    fi
}

# Display dashboard
show_dashboard() {
    clear 2>/dev/null || true

    print_header "Mattermost Dashboard"
    echo "                    $(date '+%Y-%m-%d %H:%M:%S')"

    # Health Score
    print_section "System Health"
    SCORE=$(calculate_score)
    STATUS_TEXT=$(score_status "$SCORE")
    echo "Score: $SCORE/100 [$STATUS_TEXT]"

    # Version
    VERSION=$(mmctl_json version 2>/dev/null | grep -o '"Version":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
    echo "Version: $VERSION"

    # User Statistics
    print_section "User Statistics"
    TOTAL_USERS=$(mmctl_json user list --all 2>/dev/null | grep -c '"id":' 2>/dev/null || echo "?")
    ACTIVE_USERS=$(mmctl_json user list --all 2>/dev/null | grep -v '"delete_at":[1-9]' | grep -c '"id":' 2>/dev/null || echo "?")
    echo "Total Users: $TOTAL_USERS"
    echo "Active Users: $ACTIVE_USERS"

    # Team Statistics
    print_section "Team Statistics"
    TOTAL_TEAMS=$(mmctl_json team list 2>/dev/null | grep -c '"id":' 2>/dev/null || echo "?")
    echo "Total Teams: $TOTAL_TEAMS"

    # Channel Statistics
    print_section "Channel Statistics"
    # This would need team-specific queries
    echo "Use: /scripts/channels.sh stats <team> for details"

    # Plugin Status
    print_section "Plugin Status"
    ACTIVE_PLUGINS=$(mmctl_json plugin list 2>/dev/null | grep -c '"state":2' 2>/dev/null || echo "0")
    INACTIVE_PLUGINS=$(mmctl_json plugin list 2>/dev/null | grep -c '"state":0' 2>/dev/null || echo "0")
    echo "Active Plugins: $ACTIVE_PLUGINS"
    echo "Inactive Plugins: $INACTIVE_PLUGINS"

    # Job Queue
    print_section "Job Queue"
    PENDING_JOBS=$(mmctl_json job list 2>/dev/null | grep -c '"status":"pending"' 2>/dev/null || echo "0")
    RUNNING_JOBS=$(mmctl_json job list 2>/dev/null | grep -c '"status":"in_progress"' 2>/dev/null || echo "0")
    echo "Pending Jobs: $PENDING_JOBS"
    echo "Running Jobs: $RUNNING_JOBS"

    echo ""
    echo "=============================================================="
}

# Show summary
show_summary() {
    print_header "Mattermost Summary"

    SCORE=$(calculate_score)
    STATUS_TEXT=$(score_status "$SCORE")

    echo ""
    echo "Health: $SCORE/100 [$STATUS_TEXT]"

    TOTAL_USERS=$(mmctl_json user list --all 2>/dev/null | grep -c '"id":' 2>/dev/null || echo "?")
    TOTAL_TEAMS=$(mmctl_json team list 2>/dev/null | grep -c '"id":' 2>/dev/null || echo "?")

    echo "Users: $TOTAL_USERS"
    echo "Teams: $TOTAL_TEAMS"
    echo ""
}

# Show activity feed
show_activity() {
    print_header "Recent Activity"

    print_section "Recent Logins"
    # Note: This requires audit logging to be enabled
    echo "Check audit logs for login activity:"
    echo "  /scripts/audit.sh login"

    print_section "Recent Posts"
    echo "Search recent posts with:"
    echo "  /scripts/posts.sh search <term>"

    print_section "Recent Jobs"
    mmctl_cmd job list --page 0 --per-page 10 2>/dev/null || echo "No recent jobs"
}

case "$CMD" in
summary|"")
    show_summary
    ;;

--watch|watch)
    echo "Starting dashboard in watch mode (refresh: ${WATCH_INTERVAL}s)"
    echo "Press Ctrl+C to exit"
    while true; do
        show_dashboard
        sleep "$WATCH_INTERVAL"
    done
    ;;

full)
    show_dashboard
    ;;

--json|json)
    SCORE=$(calculate_score)
    STATUS_TEXT=$(score_status "$SCORE")
    VERSION=$(mmctl_json version 2>/dev/null | grep -o '"Version":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
    TOTAL_USERS=$(mmctl_json user list --all 2>/dev/null | grep -c '"id":' 2>/dev/null || echo "0")
    TOTAL_TEAMS=$(mmctl_json team list 2>/dev/null | grep -c '"id":' 2>/dev/null || echo "0")
    ACTIVE_PLUGINS=$(mmctl_json plugin list 2>/dev/null | grep -c '"state":2' 2>/dev/null || echo "0")
    PENDING_JOBS=$(mmctl_json job list 2>/dev/null | grep -c '"status":"pending"' 2>/dev/null || echo "0")

    cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "health": {
    "score": $SCORE,
    "status": "$STATUS_TEXT"
  },
  "version": "$VERSION",
  "statistics": {
    "total_users": $TOTAL_USERS,
    "total_teams": $TOTAL_TEAMS,
    "active_plugins": $ACTIVE_PLUGINS,
    "pending_jobs": $PENDING_JOBS
  }
}
EOF
    ;;

activity)
    show_activity
    ;;

*)
    echo "Mattermost Dashboard"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  summary       Brief overview (default)"
    echo "  full          Full dashboard display"
    echo "  --watch [s]   Auto-refresh every N seconds (default: 5)"
    echo "  --json        JSON output"
    echo "  activity      Recent activity feed"
    echo ""
    echo "Dashboard Sections:"
    echo "  - System Health Score"
    echo "  - User Statistics"
    echo "  - Team/Channel counts"
    echo "  - Plugin Status"
    echo "  - Job Queue Status"
    ;;
esac
