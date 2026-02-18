#!/bin/sh
# Mattermost Import/Export Operations
# Usage: /scripts/import-export.sh [command] [args]
# Runs inside container with mmctl --local
set -e

CMD="${1:-help}"
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

# Export directory
EXPORT_DIR="/mattermost/data/export"

case "$CMD" in
# EXPORT
export)
    [ -z "$ARG1" ] && { echo "Usage: $0 export <users|teams|channels|posts|bulk>"; exit 1; }
    case "$ARG1" in
    users)
        print_header "Export Users"
        mkdir -p "$EXPORT_DIR"
        EXPORT_FILE="$EXPORT_DIR/users_$(date +%Y%m%d_%H%M%S).json"
        mmctl_json user list --all > "$EXPORT_FILE"
        echo "Users exported to: $EXPORT_FILE"
        ;;
    teams)
        print_header "Export Teams"
        mkdir -p "$EXPORT_DIR"
        EXPORT_FILE="$EXPORT_DIR/teams_$(date +%Y%m%d_%H%M%S).json"
        mmctl_json team list > "$EXPORT_FILE"
        echo "Teams exported to: $EXPORT_FILE"
        ;;
    channels)
        print_header "Export Channels"
        mkdir -p "$EXPORT_DIR"
        # Export channels from all teams
        TEAMS=$(mmctl_json team list | grep '"name"' | cut -d'"' -f4)
        EXPORT_FILE="$EXPORT_DIR/channels_$(date +%Y%m%d_%H%M%S).json"
        echo "[" > "$EXPORT_FILE"
        FIRST=true
        for TEAM in $TEAMS; do
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                echo "," >> "$EXPORT_FILE"
            fi
            echo "{\"team\": \"$TEAM\", \"channels\": " >> "$EXPORT_FILE"
            mmctl_json channel list "$TEAM" >> "$EXPORT_FILE"
            echo "}" >> "$EXPORT_FILE"
        done
        echo "]" >> "$EXPORT_FILE"
        echo "Channels exported to: $EXPORT_FILE"
        ;;
    posts)
        print_header "Export Posts (Compliance)"
        echo "For compliance message export, use:"
        echo "  mmctl export create"
        echo ""
        echo "Or trigger via jobs:"
        echo "  /scripts/jobs.sh create message_export"
        echo ""
        mmctl_cmd export create 2>/dev/null && echo "Export job created" || echo "Use jobs interface for exports"
        ;;
    bulk)
        print_header "Bulk Export"
        echo "Creating bulk export..."
        mmctl_cmd export create
        echo ""
        echo "Check export status with:"
        echo "  /scripts/jobs.sh by-type export_process"
        ;;
    actiance)
        print_header "Actiance Export"
        echo "Actiance export configuration:"
        mmctl_cmd config get MessageExportSettings.EnableExport 2>/dev/null
        mmctl_cmd config get MessageExportSettings.ExportFormat 2>/dev/null
        echo ""
        echo "Configure in System Console > Compliance > Compliance Export"
        ;;
    globalrelay)
        print_header "GlobalRelay Export"
        echo "GlobalRelay export configuration:"
        mmctl_cmd config get MessageExportSettings.GlobalRelaySettings 2>/dev/null || echo "Not configured"
        echo ""
        echo "Configure in System Console > Compliance > Compliance Export"
        ;;
    *)
        echo "Usage: $0 export <users|teams|channels|posts|bulk|actiance|globalrelay>"
        ;;
    esac
    ;;

# IMPORT
import)
    [ -z "$ARG1" ] && { echo "Usage: $0 import <file> [--validate|--dry-run]"; exit 1; }
    FILE="$ARG1"

    if [ ! -f "$FILE" ]; then
        echo "File not found: $FILE"
        exit 1
    fi

    case "$ARG2" in
    --validate)
        print_header "Validate Import File"
        mmctl_cmd import validate "$FILE"
        ;;
    --dry-run)
        print_header "Import Dry Run"
        echo "Preview of import from: $FILE"
        mmctl_cmd import process "$FILE" --bypass-upload 2>/dev/null || mmctl_cmd import upload "$FILE"
        echo ""
        echo "Check import job status with:"
        echo "  /scripts/jobs.sh by-type import_process"
        ;;
    *)
        print_header "Import Data"
        echo "Importing from: $FILE"
        mmctl_cmd import upload "$FILE"
        echo ""
        echo "Import uploaded. Process with:"
        echo "  mmctl import process <import_name>"
        echo ""
        echo "Or check status:"
        echo "  /scripts/jobs.sh by-type import_process"
        ;;
    esac
    ;;

bulk-import)
    [ -z "$ARG1" ] && { echo "Usage: $0 bulk-import <directory>"; exit 1; }
    DIR="$ARG1"

    if [ ! -d "$DIR" ]; then
        echo "Directory not found: $DIR"
        exit 1
    fi

    print_header "Bulk Import from Directory"
    echo "Directory: $DIR"
    echo ""

    # List files to import
    echo "Files found:"
    ls -la "$DIR"/*.json 2>/dev/null || ls -la "$DIR"/*.jsonl 2>/dev/null || echo "No JSON files found"
    echo ""
    echo "To import, use:"
    echo "  $0 import <file>"
    ;;

# STATUS
status)
    [ -z "$ARG1" ] && { echo "Usage: $0 status <job_id>"; exit 1; }
    print_header "Import/Export Job Status"
    mmctl_cmd job show "$ARG1" 2>/dev/null || mmctl_cmd job list | grep "$ARG1" || echo "Job not found"
    ;;

jobs)
    print_header "Import/Export Jobs"

    print_section "Import Jobs"
    mmctl_cmd job list --type import_process 2>/dev/null | head -10 || echo "No import jobs"

    print_section "Export Jobs"
    mmctl_cmd job list --type export_process 2>/dev/null | head -10 || echo "No export jobs"

    print_section "Message Export Jobs"
    mmctl_cmd job list --type message_export 2>/dev/null | head -10 || echo "No message export jobs"
    ;;

# LIST EXPORTS
list)
    print_header "Available Exports"
    mmctl_cmd export list 2>/dev/null || {
        echo "Checking export directory..."
        ls -la "$EXPORT_DIR" 2>/dev/null || echo "No exports found"
    }
    ;;

# DOWNLOAD
download)
    [ -z "$ARG1" ] && { echo "Usage: $0 download <export_name>"; exit 1; }
    print_header "Download Export"
    mmctl_cmd export download "$ARG1" 2>/dev/null || echo "Export not found or download not available"
    ;;

# DELETE EXPORT
delete-export)
    [ -z "$ARG1" ] && { echo "Usage: $0 delete-export <export_name>"; exit 1; }
    print_header "Delete Export"
    mmctl_cmd export delete "$ARG1" 2>/dev/null && echo "Export deleted" || echo "Could not delete export"
    ;;

# FORMAT INFO
format)
    print_header "Import/Export Format Reference"
    echo ""
    echo "Mattermost Bulk Import Format (JSONL):"
    echo ""
    echo "Version line (first):"
    echo '  {"type":"version","version":1}'
    echo ""
    echo "Team:"
    echo '  {"type":"team","team":{"name":"team-name","display_name":"Display Name","type":"O"}}'
    echo ""
    echo "Channel:"
    echo '  {"type":"channel","channel":{"team":"team-name","name":"channel-name","display_name":"Channel","type":"O"}}'
    echo ""
    echo "User:"
    echo '  {"type":"user","user":{"username":"user1","email":"user@example.com","teams":[{"name":"team-name"}]}}'
    echo ""
    echo "Post:"
    echo '  {"type":"post","post":{"team":"team-name","channel":"channel-name","user":"user1","message":"Hello","create_at":1234567890000}}'
    echo ""
    echo "Direct Channel:"
    echo '  {"type":"direct_channel","direct_channel":{"members":["user1","user2"]}}'
    echo ""
    echo "Documentation:"
    echo "  https://docs.mattermost.com/onboard/bulk-loading-data.html"
    ;;

# HELP
*)
    echo "Mattermost Import/Export Operations"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "EXPORT:"
    echo "  export users          Export all users to JSON"
    echo "  export teams          Export all teams to JSON"
    echo "  export channels       Export all channels to JSON"
    echo "  export posts          Export posts (compliance)"
    echo "  export bulk           Full bulk export"
    echo "  export actiance       Actiance format export"
    echo "  export globalrelay    GlobalRelay format export"
    echo ""
    echo "IMPORT:"
    echo "  import <file>              Import from file"
    echo "  import <file> --validate   Validate import file only"
    echo "  import <file> --dry-run    Preview import"
    echo "  bulk-import <directory>    Bulk import from directory"
    echo ""
    echo "STATUS:"
    echo "  status <job_id>       Check import/export job status"
    echo "  jobs                  List import/export jobs"
    echo "  list                  List available exports"
    echo ""
    echo "MANAGEMENT:"
    echo "  download <name>       Download export file"
    echo "  delete-export <name>  Delete export file"
    echo ""
    echo "REFERENCE:"
    echo "  format                Show import/export format reference"
    echo ""
    echo "Export Location: $EXPORT_DIR"
    ;;
esac
