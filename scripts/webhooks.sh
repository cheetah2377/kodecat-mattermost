#!/bin/sh
# Mattermost Webhook Management
# Usage: /scripts/webhooks.sh [command] [args]
# Runs inside container with mmctl --local
set -e

CMD="${1:-list}"
ARG1="$2"
ARG2="$3"
ARG3="$4"
ARG4="$5"

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
# LISTING - ALL
list)
    print_header "All Webhooks"

    print_section "Incoming Webhooks"
    mmctl_cmd webhook list incoming --all 2>/dev/null || echo "No incoming webhooks"

    print_section "Outgoing Webhooks"
    mmctl_cmd webhook list outgoing --all 2>/dev/null || echo "No outgoing webhooks"
    ;;

# INCOMING WEBHOOKS
incoming)
    print_header "Incoming Webhooks"
    if [ -z "$ARG1" ]; then
        mmctl_cmd webhook list incoming --all
    else
        # List for specific team
        mmctl_cmd webhook list incoming "$ARG1"
    fi
    ;;

create-in)
    [ -z "$ARG1" ] && { echo "Usage: $0 create-in <channel> [display_name] [description]"; exit 1; }
    CHANNEL="$ARG1"
    DISPLAY_NAME="${ARG2:-Incoming Webhook}"
    DESCRIPTION="${ARG3:-}"

    print_header "Create Incoming Webhook"
    if [ -n "$DESCRIPTION" ]; then
        mmctl_cmd webhook create-incoming --channel "$CHANNEL" --display-name "$DISPLAY_NAME" --description "$DESCRIPTION"
    else
        mmctl_cmd webhook create-incoming --channel "$CHANNEL" --display-name "$DISPLAY_NAME"
    fi
    echo ""
    echo "Webhook created for channel: $CHANNEL"
    ;;

get-in)
    [ -z "$ARG1" ] && { echo "Usage: $0 get-in <webhook_id>"; exit 1; }
    print_header "Incoming Webhook Details"
    mmctl_cmd webhook show "$ARG1"
    ;;

delete-in)
    [ -z "$ARG1" ] && { echo "Usage: $0 delete-in <webhook_id>"; exit 1; }
    print_header "Delete Incoming Webhook"
    mmctl_cmd webhook delete "$ARG1"
    echo "Webhook $ARG1 deleted"
    ;;

regenerate-in)
    [ -z "$ARG1" ] && { echo "Usage: $0 regenerate-in <webhook_id>"; exit 1; }
    print_header "Regenerate Incoming Webhook Token"
    # Note: mmctl doesn't directly support regenerating tokens
    echo "Token regeneration requires:"
    echo "1. Delete the existing webhook"
    echo "2. Create a new webhook with the same settings"
    echo ""
    echo "Current webhook:"
    mmctl_cmd webhook show "$ARG1"
    ;;

# OUTGOING WEBHOOKS
outgoing)
    print_header "Outgoing Webhooks"
    if [ -z "$ARG1" ]; then
        mmctl_cmd webhook list outgoing --all
    else
        mmctl_cmd webhook list outgoing "$ARG1"
    fi
    ;;

create-out)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] || [ -z "$ARG3" ] && { echo "Usage: $0 create-out <channel> <trigger_word> <callback_url>"; exit 1; }
    CHANNEL="$ARG1"
    TRIGGER="$ARG2"
    CALLBACK="$ARG3"

    print_header "Create Outgoing Webhook"
    mmctl_cmd webhook create-outgoing --channel "$CHANNEL" --trigger-word "$TRIGGER" --url "$CALLBACK"
    echo ""
    echo "Outgoing webhook created"
    echo "Channel: $CHANNEL"
    echo "Trigger: $TRIGGER"
    echo "Callback: $CALLBACK"
    ;;

get-out)
    [ -z "$ARG1" ] && { echo "Usage: $0 get-out <webhook_id>"; exit 1; }
    print_header "Outgoing Webhook Details"
    mmctl_cmd webhook show "$ARG1"
    ;;

delete-out)
    [ -z "$ARG1" ] && { echo "Usage: $0 delete-out <webhook_id>"; exit 1; }
    print_header "Delete Outgoing Webhook"
    mmctl_cmd webhook delete "$ARG1"
    echo "Webhook $ARG1 deleted"
    ;;

regenerate-out)
    [ -z "$ARG1" ] && { echo "Usage: $0 regenerate-out <webhook_id>"; exit 1; }
    print_header "Regenerate Outgoing Webhook Token"
    echo "Token regeneration requires:"
    echo "1. Delete the existing webhook"
    echo "2. Create a new webhook with the same settings"
    echo ""
    echo "Current webhook:"
    mmctl_cmd webhook show "$ARG1"
    ;;

# TESTING
test)
    [ -z "$ARG1" ] || [ -z "$ARG2" ] && { echo "Usage: $0 test <webhook_url> <message>"; exit 1; }
    WEBHOOK_URL="$ARG1"
    MESSAGE="$ARG2"

    print_header "Test Webhook"
    echo "Sending test message to webhook..."
    echo ""

    # Use curl to send test payload
    if command -v curl >/dev/null 2>&1; then
        curl -s -X POST -H 'Content-Type: application/json' \
            -d "{\"text\": \"$MESSAGE\"}" \
            "$WEBHOOK_URL" && echo "" && echo "Test message sent" || echo "Failed to send test message"
    else
        echo "curl not available"
        echo ""
        echo "Manual test command:"
        echo "curl -X POST -H 'Content-Type: application/json' \\"
        echo "  -d '{\"text\": \"$MESSAGE\"}' \\"
        echo "  '$WEBHOOK_URL'"
    fi
    ;;

# MODIFY
modify)
    [ -z "$ARG1" ] && { echo "Usage: $0 modify <webhook_id> <setting> <value>"; exit 1; }
    print_header "Modify Webhook"
    mmctl_cmd webhook modify "$ARG1" "$ARG2" "$ARG3"
    echo "Webhook modified"
    ;;

# HELP
*)
    echo "Mattermost Webhook Management"
    echo ""
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "LISTING:"
    echo "  list                  List all webhooks (default)"
    echo ""
    echo "INCOMING WEBHOOKS:"
    echo "  incoming [team]       List incoming webhooks"
    echo "  create-in <channel> [name] [desc]   Create incoming webhook"
    echo "  get-in <hook_id>      Get incoming webhook details"
    echo "  delete-in <hook_id>   Delete incoming webhook"
    echo "  regenerate-in <id>    Regenerate token"
    echo ""
    echo "OUTGOING WEBHOOKS:"
    echo "  outgoing [team]       List outgoing webhooks"
    echo "  create-out <channel> <trigger> <url>   Create outgoing webhook"
    echo "  get-out <hook_id>     Get outgoing webhook details"
    echo "  delete-out <hook_id>  Delete outgoing webhook"
    echo "  regenerate-out <id>   Regenerate token"
    echo ""
    echo "TESTING:"
    echo "  test <url> <message>  Send test payload to webhook"
    echo ""
    echo "MODIFY:"
    echo "  modify <id> <setting> <value>   Modify webhook setting"
    echo ""
    echo "Webhook Payload Format:"
    echo "  {\"text\": \"Message text\"}"
    echo "  {\"text\": \"Message\", \"channel\": \"channel-name\"}"
    echo "  {\"text\": \"Message\", \"username\": \"webhook-bot\"}"
    ;;
esac
