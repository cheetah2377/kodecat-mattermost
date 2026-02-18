#!/bin/sh
# Mattermost Health Check
# Usage: /scripts/health.sh [command]
# Runs inside container with mmctl --local
set -e

CMD="${1:-status}"

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

# Calculate health score (0-100)
calculate_score() {
    SCORE=100

    # Check system status
    STATUS=$(mmctl_json system status 2>/dev/null || echo '{"status":"error"}')

    # Database check (-40 if not OK)
    DB_STATUS=$(echo "$STATUS" | grep -o '"DatabaseStatus":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "error")
    if [ "$DB_STATUS" != "OK" ]; then
        SCORE=$((SCORE - 40))
    fi

    # Filestore check (-20 if not OK)
    FS_STATUS=$(echo "$STATUS" | grep -o '"FileStoreStatus":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "error")
    if [ "$FS_STATUS" != "OK" ]; then
        SCORE=$((SCORE - 20))
    fi

    # Check for high connection count (-10 if >80%)
    # This would need actual metrics from prometheus/grafana integration

    # Check job queue (-15 if >100 pending)
    PENDING_JOBS=$(mmctl_json job list --all 2>/dev/null | grep -c '"status":"pending"' 2>/dev/null || echo "0")
    if [ "$PENDING_JOBS" -gt 100 ] 2>/dev/null; then
        SCORE=$((SCORE - 15))
    fi

    # Ensure score is not negative
    if [ "$SCORE" -lt 0 ]; then
        SCORE=0
    fi

    echo "$SCORE"
}

# Get score status text
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

case "$CMD" in
status|"")
    print_header "Mattermost Health Status"

    SCORE=$(calculate_score)
    STATUS_TEXT=$(score_status "$SCORE")

    echo ""
    echo "Health Score: $SCORE/100 [$STATUS_TEXT]"
    echo ""

    print_section "System Status"
    mmctl_cmd system status

    print_section "Version"
    mmctl_cmd version
    ;;

--json|json)
    SCORE=$(calculate_score)
    STATUS_TEXT=$(score_status "$SCORE")
    SYS_STATUS=$(mmctl_json system status 2>/dev/null || echo '{}')

    # Build JSON output
    cat <<EOF
{
  "score": $SCORE,
  "status": "$STATUS_TEXT",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "system": $SYS_STATUS
}
EOF
    ;;

quick)
    SCORE=$(calculate_score)
    STATUS_TEXT=$(score_status "$SCORE")
    echo "$STATUS_TEXT ($SCORE/100)"
    ;;

metrics)
    print_header "Prometheus Metrics"

    SCORE=$(calculate_score)
    STATUS=$(mmctl_json system status 2>/dev/null || echo '{}')

    # Output Prometheus-style metrics
    echo "# HELP mattermost_health_score System health score 0-100"
    echo "# TYPE mattermost_health_score gauge"
    echo "mattermost_health_score $SCORE"

    echo ""
    echo "# HELP mattermost_up Is Mattermost responding"
    echo "# TYPE mattermost_up gauge"
    if [ "$SCORE" -gt 0 ]; then
        echo "mattermost_up 1"
    else
        echo "mattermost_up 0"
    fi

    # Database status
    DB_STATUS=$(echo "$STATUS" | grep -o '"DatabaseStatus":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "error")
    echo ""
    echo "# HELP mattermost_database_up Is database connection OK"
    echo "# TYPE mattermost_database_up gauge"
    if [ "$DB_STATUS" = "OK" ]; then
        echo "mattermost_database_up 1"
    else
        echo "mattermost_database_up 0"
    fi

    # Filestore status
    FS_STATUS=$(echo "$STATUS" | grep -o '"FileStoreStatus":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "error")
    echo ""
    echo "# HELP mattermost_filestore_up Is filestore connection OK"
    echo "# TYPE mattermost_filestore_up gauge"
    if [ "$FS_STATUS" = "OK" ]; then
        echo "mattermost_filestore_up 1"
    else
        echo "mattermost_filestore_up 0"
    fi
    ;;

components)
    print_header "Component Health"

    STATUS=$(mmctl_json system status 2>/dev/null || echo '{}')

    print_section "Database"
    DB_STATUS=$(echo "$STATUS" | grep -o '"DatabaseStatus":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "UNKNOWN")
    echo "Status: $DB_STATUS"

    print_section "Filestore"
    FS_STATUS=$(echo "$STATUS" | grep -o '"FileStoreStatus":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "UNKNOWN")
    echo "Status: $FS_STATUS"

    print_section "Email"
    # Test email would require additional configuration
    echo "Use: /scripts/config.sh test-email to test email"

    print_section "Push Notifications"
    echo "Use: /scripts/config.sh test-push to test push notifications"
    ;;

*)
    echo "Mattermost Health Check"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status        Full health check with score (default)"
    echo "  --json        JSON output for monitoring integration"
    echo "  quick         Quick status only (OK/WARN/ERROR)"
    echo "  metrics       Prometheus-style metrics output"
    echo "  components    Check individual components (db, filestore)"
    echo ""
    echo "Score Calculation:"
    echo "  - Database status: -40 if not OK"
    echo "  - Filestore status: -20 if not OK"
    echo "  - Job queue backup: -15 if >100 pending"
    ;;
esac
