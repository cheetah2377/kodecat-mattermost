#!/bin/sh
# Mattermost Audit & Compliance Logs
# Usage: /scripts/audit.sh [command] [args]
# Runs inside container with mmctl --local
set -e

CMD="${1:-logs}"
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

# Get audit log file path
AUDIT_LOG="/mattermost/logs/mattermost.log"

case "$CMD" in
# LOGS
logs)
    print_header "Audit Logs"

    if [ "$ARG1" = "--json" ]; then
        tail -n 200 "$AUDIT_LOG" 2>/dev/null | grep '"audit"' || echo "No audit logs found"
    elif [ "$ARG1" = "--since" ] && [ -n "$ARG2" ]; then
        echo "Logs since: $ARG2"
        grep "$ARG2" "$AUDIT_LOG" 2>/dev/null | tail -100 || echo "No logs found for date: $ARG2"
    else
        PAGE="${ARG1:-100}"
        tail -n "$PAGE" "$AUDIT_LOG" 2>/dev/null | grep -i "audit\|login\|logout\|created\|deleted\|modified" | tail -50 || echo "No audit-related logs found"
    fi
    ;;

# FILTERS
login)
    print_header "Login Events"

    if [ "$ARG1" = "--failed" ]; then
        echo "Failed Login Attempts:"
        grep -i "failed.*login\|login.*fail\|authentication.*fail" "$AUDIT_LOG" 2>/dev/null | tail -50 || echo "No failed logins found"
    else
        grep -i "login\|logged.in" "$AUDIT_LOG" 2>/dev/null | tail -50 || echo "No login events found"
    fi
    ;;

logout)
    print_header "Logout Events"
    grep -i "logout\|logged.out\|session.*revoke" "$AUDIT_LOG" 2>/dev/null | tail -50 || echo "No logout events found"
    ;;

admin)
    print_header "Admin Actions"
    grep -i "admin\|system.console\|config.*change" "$AUDIT_LOG" 2>/dev/null | tail -50 || echo "No admin actions found"
    ;;

config)
    print_header "Configuration Changes"
    grep -i "config.*update\|config.*change\|setting.*change" "$AUDIT_LOG" 2>/dev/null | tail -50 || echo "No config changes found"
    ;;

user)
    print_header "User Modifications"
    grep -i "user.*create\|user.*delete\|user.*update\|user.*deactivate\|user.*activate" "$AUDIT_LOG" 2>/dev/null | tail -50 || echo "No user modifications found"
    ;;

team)
    print_header "Team Modifications"
    grep -i "team.*create\|team.*delete\|team.*update\|team.*add\|team.*remove" "$AUDIT_LOG" 2>/dev/null | tail -50 || echo "No team modifications found"
    ;;

channel)
    print_header "Channel Modifications"
    grep -i "channel.*create\|channel.*delete\|channel.*update\|channel.*archive" "$AUDIT_LOG" 2>/dev/null | tail -50 || echo "No channel modifications found"
    ;;

post)
    print_header "Post Actions"
    grep -i "post.*create\|post.*delete\|post.*update" "$AUDIT_LOG" 2>/dev/null | tail -30 || echo "No post actions found"
    ;;

permission)
    print_header "Permission Changes"
    grep -i "permission\|role.*change\|role.*assign" "$AUDIT_LOG" 2>/dev/null | tail -50 || echo "No permission changes found"
    ;;

# EXPORT
export)
    print_header "Export Audit Logs"

    EXPORT_FILE="/tmp/audit_export_$(date +%Y%m%d_%H%M%S).log"

    if [ "$ARG1" = "--since" ] && [ -n "$ARG2" ]; then
        echo "Exporting logs since: $ARG2"
        grep "$ARG2" "$AUDIT_LOG" > "$EXPORT_FILE" 2>/dev/null
    else
        echo "Exporting all audit-related logs..."
        grep -i "audit\|login\|logout\|created\|deleted\|modified\|permission\|config" "$AUDIT_LOG" > "$EXPORT_FILE" 2>/dev/null
    fi

    if [ -f "$EXPORT_FILE" ] && [ -s "$EXPORT_FILE" ]; then
        LINES=$(wc -l < "$EXPORT_FILE")
        echo "Exported $LINES lines to: $EXPORT_FILE"
    else
        echo "No matching logs to export"
        rm -f "$EXPORT_FILE"
    fi
    ;;

# COMPLIANCE
compliance)
    print_header "Compliance Summary"

    if [ "$ARG1" = "--json" ]; then
        echo "{"

        # Count events
        LOGINS=$(grep -ci "login\|logged.in" "$AUDIT_LOG" 2>/dev/null || echo "0")
        FAILED=$(grep -ci "failed.*login\|login.*fail" "$AUDIT_LOG" 2>/dev/null || echo "0")
        USERS=$(grep -ci "user.*create\|user.*delete" "$AUDIT_LOG" 2>/dev/null || echo "0")
        CONFIG=$(grep -ci "config.*change\|setting.*change" "$AUDIT_LOG" 2>/dev/null || echo "0")

        echo "  \"login_events\": $LOGINS,"
        echo "  \"failed_logins\": $FAILED,"
        echo "  \"user_changes\": $USERS,"
        echo "  \"config_changes\": $CONFIG,"
        echo "  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
        echo "}"
    else
        echo ""
        echo "Event Summary (from available logs):"
        echo ""

        LOGINS=$(grep -ci "login\|logged.in" "$AUDIT_LOG" 2>/dev/null || echo "0")
        echo "Login Events: $LOGINS"

        FAILED=$(grep -ci "failed.*login\|login.*fail" "$AUDIT_LOG" 2>/dev/null || echo "0")
        echo "Failed Logins: $FAILED"

        USERS=$(grep -ci "user.*create\|user.*delete" "$AUDIT_LOG" 2>/dev/null || echo "0")
        echo "User Changes: $USERS"

        TEAMS=$(grep -ci "team.*create\|team.*delete" "$AUDIT_LOG" 2>/dev/null || echo "0")
        echo "Team Changes: $TEAMS"

        CHANNELS=$(grep -ci "channel.*create\|channel.*delete\|channel.*archive" "$AUDIT_LOG" 2>/dev/null || echo "0")
        echo "Channel Changes: $CHANNELS"

        CONFIG=$(grep -ci "config.*change\|setting.*change" "$AUDIT_LOG" 2>/dev/null || echo "0")
        echo "Config Changes: $CONFIG"

        echo ""
        echo "Generated: $(date)"
    fi
    ;;

# RECENT
recent)
    print_header "Recent Audit Events"
    LINES="${ARG1:-50}"
    tail -n 500 "$AUDIT_LOG" 2>/dev/null | grep -i "audit\|login\|logout\|created\|deleted\|modified" | tail -n "$LINES" || echo "No recent audit events"
    ;;

# SEARCH
search)
    [ -z "$ARG1" ] && { echo "Usage: $0 search <term>"; exit 1; }
    print_header "Search Audit Logs: $ARG1"
    grep -i "$ARG1" "$AUDIT_LOG" 2>/dev/null | tail -100 || echo "No matches found for: $ARG1"
    ;;

# DATA RETENTION STATUS
retention)
    print_header "Data Retention Status"
    echo "Data Retention Configuration:"
    mmctl_cmd config get DataRetentionSettings.EnableMessageDeletion 2>/dev/null || echo "Not configured"
    mmctl_cmd config get DataRetentionSettings.MessageRetentionDays 2>/dev/null || echo "N/A"

    print_section "Recent Retention Jobs"
    mmctl_cmd job list --type data_retention 2>/dev/null | head -10 || echo "No retention jobs found"
    ;;

# HELP
*)
    echo "Mattermost Audit & Compliance Logs"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "LOGS:"
    echo "  logs [lines]          View audit logs (default: 100)"
    echo "  logs --json           JSON output"
    echo "  logs --since <date>   Logs since date"
    echo "  recent [lines]        Recent audit events"
    echo ""
    echo "FILTERS:"
    echo "  login                 Login/logout events"
    echo "  login --failed        Failed login attempts"
    echo "  logout                Logout events"
    echo "  admin                 Admin actions"
    echo "  config                Config changes"
    echo "  user                  User modifications"
    echo "  team                  Team modifications"
    echo "  channel               Channel modifications"
    echo "  post                  Post actions"
    echo "  permission            Permission changes"
    echo ""
    echo "SEARCH:"
    echo "  search <term>         Search audit logs"
    echo ""
    echo "EXPORT:"
    echo "  export                Export all audit logs"
    echo "  export --since <date> Export since date"
    echo ""
    echo "COMPLIANCE:"
    echo "  compliance            Compliance summary report"
    echo "  compliance --json     JSON format"
    echo "  retention             Data retention status"
    echo ""
    echo "Note: Audit logging detail depends on server configuration."
    echo "Enable detailed audit logging in System Console > Compliance."
    ;;
esac
