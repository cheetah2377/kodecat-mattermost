#!/bin/sh
# Mattermost Job Management
# Usage: /scripts/jobs.sh [command] [args]
# Runs inside container with mmctl --local
set -e

CMD="${1:-list}"
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
# LISTING
list)
    print_header "Mattermost Jobs"
    if [ "$ARG1" = "--json" ]; then
        mmctl_json job list --all
    else
        PAGE="${ARG1:-0}"
        mmctl_cmd job list --page "$PAGE" --per-page 20
    fi
    ;;

pending)
    print_header "Pending Jobs"
    mmctl_cmd job list --status pending 2>/dev/null || mmctl_cmd job list | grep -i pending || echo "No pending jobs"
    ;;

active|in-progress|running)
    print_header "Running Jobs"
    mmctl_cmd job list --status in_progress 2>/dev/null || mmctl_cmd job list | grep -i "in.progress" || echo "No running jobs"
    ;;

completed)
    print_header "Completed Jobs"
    mmctl_cmd job list --status success 2>/dev/null || mmctl_cmd job list | grep -i success | head -20 || echo "No completed jobs"
    ;;

failed)
    print_header "Failed Jobs"
    mmctl_cmd job list --status error 2>/dev/null || mmctl_cmd job list | grep -i "error\|failed" || echo "No failed jobs"
    ;;

by-type)
    [ -z "$ARG1" ] && { echo "Usage: $0 by-type <job_type>"; exit 1; }
    print_header "Jobs: $ARG1"
    mmctl_cmd job list --type "$ARG1"
    ;;

# MANAGEMENT
get)
    [ -z "$ARG1" ] && { echo "Usage: $0 get <job_id>"; exit 1; }
    print_header "Job Details"
    mmctl_cmd job show "$ARG1" 2>/dev/null || mmctl_json job list | grep -A20 "\"id\":\"$ARG1\"" || echo "Job not found"
    ;;

cancel)
    [ -z "$ARG1" ] && { echo "Usage: $0 cancel <job_id>"; exit 1; }
    print_header "Cancel Job"
    mmctl_cmd job cancel "$ARG1" 2>/dev/null && echo "Job $ARG1 cancelled" || echo "Cannot cancel job (may already be completed or not cancellable)"
    ;;

retry)
    [ -z "$ARG1" ] && { echo "Usage: $0 retry <job_id>"; exit 1; }
    print_header "Retry Failed Job"
    # Get job type first
    JOB_TYPE=$(mmctl_json job list | grep -B5 "\"id\":\"$ARG1\"" | grep '"type"' | cut -d'"' -f4)
    if [ -n "$JOB_TYPE" ]; then
        mmctl_cmd job create "$JOB_TYPE"
        echo "New $JOB_TYPE job created"
    else
        echo "Could not determine job type"
    fi
    ;;

# CREATE JOBS
create)
    [ -z "$ARG1" ] && { echo "Usage: $0 create <job_type>"; exit 1; }
    print_header "Create Job"
    mmctl_cmd job create "$ARG1"
    echo "Job created: $ARG1"
    ;;

# JOB TYPES
types)
    print_header "Available Job Types"
    echo ""
    echo "Data Management:"
    echo "  data_retention           Data retention cleanup"
    echo "  message_export           Message export (compliance)"
    echo "  import_process           Process import file"
    echo "  export_process           Create export file"
    echo ""
    echo "Search:"
    echo "  elasticsearch_post_indexing   Index posts to Elasticsearch"
    echo "  elasticsearch_post_aggregation   Aggregate post index"
    echo "  bleve_post_indexing      Index posts to Bleve"
    echo ""
    echo "Synchronization:"
    echo "  ldap_sync                LDAP synchronization"
    echo ""
    echo "Maintenance:"
    echo "  migrations               Database migrations"
    echo "  plugins                  Plugin operations"
    echo "  expiry_notify            Send expiry notifications"
    echo "  product_notices          Fetch product notices"
    echo "  resend_invitation_email  Resend invitations"
    echo "  extract_content          Extract file content"
    echo ""
    echo "Usage: $0 create <job_type>"
    ;;

# TRIGGER COMMON JOBS
trigger-ldap)
    print_header "Trigger LDAP Sync"
    mmctl_cmd ldap sync
    echo "LDAP sync job triggered"
    ;;

trigger-export)
    print_header "Trigger Message Export"
    mmctl_cmd job create message_export
    echo "Message export job created"
    ;;

trigger-retention)
    print_header "Trigger Data Retention"
    mmctl_cmd job create data_retention
    echo "Data retention job created"
    ;;

trigger-index)
    print_header "Trigger Search Index"
    # Try Elasticsearch first, fall back to Bleve
    mmctl_cmd job create elasticsearch_post_indexing 2>/dev/null || \
    mmctl_cmd job create bleve_post_indexing 2>/dev/null || \
    echo "No search indexing available"
    echo "Search indexing job created"
    ;;

# STATUS
status)
    print_header "Job Queue Status"

    PENDING=$(mmctl_json job list 2>/dev/null | grep -c '"status":"pending"' || echo "0")
    RUNNING=$(mmctl_json job list 2>/dev/null | grep -c '"status":"in_progress"' || echo "0")
    FAILED=$(mmctl_json job list 2>/dev/null | grep -c '"status":"error"' || echo "0")

    echo ""
    echo "Pending Jobs: $PENDING"
    echo "Running Jobs: $RUNNING"
    echo "Failed Jobs: $FAILED"

    if [ "$RUNNING" -gt 0 ]; then
        print_section "Running Jobs"
        mmctl_cmd job list | grep -i "in.progress" || true
    fi

    if [ "$FAILED" -gt 0 ]; then
        print_section "Recent Failures"
        mmctl_cmd job list | grep -i "error\|failed" | head -5 || true
    fi
    ;;

# HELP
*)
    echo "Mattermost Job Management"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "LISTING:"
    echo "  list [page]           List all jobs (default)"
    echo "  list --json           JSON output"
    echo "  pending               Show pending jobs"
    echo "  active                Show running jobs"
    echo "  completed             Show completed jobs"
    echo "  failed                Show failed jobs"
    echo "  by-type <type>        Filter by job type"
    echo "  status                Job queue status summary"
    echo ""
    echo "MANAGEMENT:"
    echo "  get <job_id>          Get job details"
    echo "  cancel <job_id>       Cancel pending/running job"
    echo "  retry <job_id>        Retry failed job"
    echo "  create <type>         Create new job"
    echo ""
    echo "COMMON TRIGGERS:"
    echo "  trigger-ldap          Trigger LDAP sync"
    echo "  trigger-export        Trigger message export"
    echo "  trigger-retention     Trigger data retention"
    echo "  trigger-index         Trigger search indexing"
    echo ""
    echo "REFERENCE:"
    echo "  types                 List available job types"
    echo ""
    echo "Common Job Types:"
    echo "  data_retention        Clean old data"
    echo "  message_export        Export messages"
    echo "  ldap_sync             LDAP synchronization"
    echo "  elasticsearch_post_indexing   Search indexing"
    echo "  import_process        Process import"
    echo "  export_process        Create export"
    ;;
esac
